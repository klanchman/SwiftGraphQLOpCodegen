import ArgumentParser
import Foundation
import PathKit

private let pathTransform = { (s: String) in Path(s) }

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
                    print("Overwrite existing file at '\(fileOutputPath)'? (y/n) ", terminator: "")
                    let answer = readLine()
                    if answer?.lowercased() == "y" {
                        try fileOutputPath.delete()
                    } else {
                        // TODO: Info log
                        print("Skipping \(fileOutputPath)")
                        continue
                    }
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
            abstract: "Generate Swift code from GraphQL operations."
        )

        @Option(
            name: .shortAndLong,
            help: "The directory where the generated files will be saved.",
            completion: .directory,
            transform: pathTransform
        )
        var output: Path

        @Flag(name: .long, help: "Overwrite existing files without prompting.")
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
            }

            do {
                let generatedFiles = try SwiftCodeGenerator(
                    sources: sources,
                    protocolTemplate: protocolTemplate,
                    operationTemplate: operationTemplate
                ).generate()

                if output.exists {
                    if !overwrite {
                        print("Delete existing files at '\(output)'? (y/n) ", terminator: "")
                        let answer = readLine()
                        if answer?.lowercased() != "y" {
                            Self.exit(withError: ExecutionError.aborted)
                        }
                    }
                    try output.delete()
                }

                try output.mkpath()

                for file in generatedFiles {
                    try (output + file.path).write(file.content)
                }
            } catch {
                // TODO: Error log
                print("\nError running codegen: \(error)")
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
