import ArgumentParser
import Foundation
import PathKit

public struct SwiftGraphQLOpCodegen: ParsableCommand {
    public static var configuration: CommandConfiguration = .init(
        commandName: "swift-graphql-op-codegen",
        abstract: "A utility that generates Swift code from GraphQL operations.",
        subcommands: [ExportTemplates.self, Generate.self],
        defaultSubcommand: Generate.self
    )

    public init() {}
}

extension SwiftGraphQLOpCodegen {
    struct ExportTemplates: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Export codegen templates to customize generated Swift code."
        )

        @Argument(
            help: """
                The directory where the templates will be saved.
                The directory will be created if it does not exist.
                """,
            completion: .directory,
            transform: pathTransform
        )
        var outputPath: Path

        init() {}

        func validate() throws {
            let exists = outputPath.exists
            let isDir = outputPath.isDirectory

            if exists && !isDir {
                throw ValidationError(
                    "Output path refers to an existing file, but must be a directory"
                )
            }
        }

        public func run() throws {
            if !outputPath.exists {
                try outputPath.mkpath()
            }

            guard
                let templates = Bundle.module.urls(
                    forResourcesWithExtension: "stencil",
                    subdirectory: "Templates"
                )
            else {
                throw ExecutionError.couldNotReadTemplates
            }

            for template in templates {
                let path = Path(template.path)
                let filename = template.lastPathComponent
                let fileOutputPath = outputPath + Path(filename)

                if fileOutputPath.exists {
                    guard
                        destructivePromptIfNeeded("Overwrite existing file at '\(fileOutputPath)'?")
                    else {
                        // TODO: Info log
                        print("Skipping \(fileOutputPath)")
                        continue
                    }

                    try fileOutputPath.delete()
                }

                try path.copy(fileOutputPath)
            }
        }

        enum ExecutionError: Error, CustomStringConvertible {
            case couldNotReadTemplates

            var description: String {
                switch self {
                case .couldNotReadTemplates: "Could not read template files"
                }
            }
        }
    }

    struct Generate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate Swift code from GraphQL operations.",
            discussion: """
                The tool can operate in two modes: multi-file (the default), and single-file.
                In multi-file mode, one Swift file is created per GraphQL file, plus another Swift file containing common types.
                In single-file mode, all operations and common types are combined into a single Swift file,
                which can be easier to deal with if using Xcode.

                EXAMPLES:
                Multi-file: swift-graphql-op-codegen generate --output Example/Generated/Multiple Example/GraphQL/**/*.graphql
                Single-file: swift-graphql-op-codegen generate --single-file --output Example/Generated/SingleFile.swift Example/GraphQL/**/*.graphql
                """
        )

        @Option(
            name: .shortAndLong,
            help: """
                In multi-file mode: the directory where the generated files will be saved.
                In single-file mode: the path where the generated file that will be saved.
                """,
            transform: pathTransform
        )
        var output: Path

        @Flag(
            name: .long,
            help: "Output generated code as a single file."
        )
        var singleFile = false

        @Flag(
            name: .long,
            help: "Overwrite existing files and delete extraneous files without prompting."
        )
        var overwrite = false

        @Option(
            name: .shortAndLong,
            help: """
                A directory containing custom codegen template files (refer to the `export-templates` command).
                Template file names must match those given by the `export-templates` command.
                """,
            completion: .directory,
            transform: pathTransform
        )
        var templatePath: Path?

        @Argument(
            help: ArgumentHelp(
                "Paths to files containing GraphQL operations to transform into Swift code.",
                valueName: "graphql-files"
            ),
            transform: pathTransform
        ) var files: [Path]

        init() {}

        func validate() throws {
            if singleFile {
                if output.exists && output.isDirectory {
                    throw ValidationError(
                        "'--single-file' mode expects '--output' to be a file, but a directory was provided"
                    )
                }
            } else {
                if output.exists && !output.isDirectory {
                    throw ValidationError(
                        "'--output' should be the path to a directory, but a file was provided"
                    )
                }
            }
        }

        func run() throws {
            // TODO: Debug log
            print("You gave us these files: \(files)")

            var sources = [File]()

            for file in files {
                do {
                    sources.append(File(path: file, content: try file.read()))
                } catch {
                    // TODO: Warning log
                    print("Warning: Could not read file '\(file)': \(error)")
                    continue
                }
            }

            var allOperationsTemplate: File?
            var operationTemplate: File?
            var protocolTemplate: File?

            if let templatePath {
                let opPath = templatePath + Path("Operation.stencil")
                if opPath.isFile {
                    operationTemplate = File(path: opPath, content: try opPath.read())
                }

                let protoPath = templatePath + Path("GraphQLOperation.stencil")
                if protoPath.isFile {
                    protocolTemplate = File(path: protoPath, content: try protoPath.read())
                }

                let allOpPath = templatePath + Path("AllOperations.stencil")
                if allOpPath.isFile {
                    allOperationsTemplate = File(path: allOpPath, content: try allOpPath.read())
                }
            }

            do {
                let generatedFiles = try SwiftCodeGenerator(
                    sources: sources,
                    singleFileMode: singleFile,
                    protocolTemplate: protocolTemplate,
                    operationTemplate: operationTemplate,
                    allOperationsTemplate: allOperationsTemplate
                ).generate()

                if singleFile {
                    precondition(
                        generatedFiles.count == 1,
                        "Expected to generate 1 file, but got \(generatedFiles.count)"
                    )

                    try writeOneFile(generatedFiles.first!)
                } else {
                    try writeMultipleFiles(generatedFiles)
                }
            } catch {
                // TODO: Error log
                print("\nError running codegen: \(error)")
            }
        }

        private func writeOneFile(_ file: File) throws {
            if output.exists {
                if try output.read() == file.content {
                    // TODO: Info log
                    print("Contents of \(output) did not change, not saving")
                } else if destructivePromptIfNeeded(
                    "Overwrite '\(output)'?",
                    overrideFlag: overwrite
                ) {
                    try output.delete()
                    try output.write(file.content)
                } else {
                    // TODO: Info log
                    print("Skipping \(output)")
                }
            } else {
                try output.write(file.content)
            }
        }

        private func writeMultipleFiles(_ generatedFiles: [File]) throws {
            if !output.exists {
                try output.mkpath()
                for file in generatedFiles {
                    try (output + file.path).write(file.content)
                }
            } else {
                let existingFiles = try output.children()

                for file in generatedFiles {
                    let filePath = output + file.path
                    if filePath.exists {
                        if try filePath.read() == file.content {
                            // TODO: Info log
                            print("Contents of \(file.path) did not change, not saving")
                            continue
                        } else {
                            guard
                                destructivePromptIfNeeded(
                                    "Overwrite '\(filePath)'?",
                                    overrideFlag: overwrite
                                )
                            else {
                                // TODO: Info log
                                print("Skipping \(filePath)")
                                continue
                            }

                            try filePath.delete()
                        }
                    }

                    try filePath.write(file.content)
                }

                let extraneousFiles = existingFiles.filter { existing in
                    !generatedFiles.contains { output + $0.path == existing }
                }
                if !extraneousFiles.isEmpty {
                    if destructivePromptIfNeeded(
                        """
                        Delete the following extraneous files?
                        \(extraneousFiles.map(String.init).joined(separator: "\n"))
                        """,
                        overrideFlag: overwrite
                    ) {
                        for file in extraneousFiles {
                            try file.delete()
                        }
                    } else {
                        // TODO: Info log
                        print("Keeping extraneous files")
                    }
                }
            }
        }

        enum ExecutionError: Error, CustomStringConvertible {
            case aborted
            case couldNotSaveFile

            var description: String {
                switch self {
                case .aborted: "User aborted"
                case .couldNotSaveFile: "The file could not be saved"
                }
            }
        }
    }
}

private let pathTransform = { (s: String) in Path(s) }

/// Get the user's consent before performing a destructive action if needed.
///
/// The provided message is printed with a "(y/N)" prompt following it. The user
/// must enter "y" or "Y" to perform the action. Any other input is treated as
/// refusal. If `overrideFlag` is true, this function returns true without
/// prompting the user.
///
/// - Parameters:
///   - message: The prompt to show to the user
///   - overrideFlag: A flag the user can pass to the command indicating whether to skip
///     these kinds of prompts
/// - Returns: a Bool indicating whether permission was granted to perform the action
private func destructivePromptIfNeeded(
    _ message: String,
    overrideFlag: Bool? = nil
) -> Bool {
    guard overrideFlag != true else { return true }
    let promptSeparator = message.contains("\n") ? "\n" : " "
    let finalMessage = message + promptSeparator + "(y/N)"
    print(finalMessage, terminator: " ")
    let answer = readLine()
    return answer?.lowercased() == "y"
}
