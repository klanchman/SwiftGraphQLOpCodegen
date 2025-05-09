import ArgumentParser
import Foundation

public struct SwiftGraphQLOpCodegen: ParsableCommand {
    public static var configuration: CommandConfiguration = .init(
        commandName: "swift-graphql-op-codegen"
    )

    @Option(
        name: .shortAndLong,
        help: "The directory into which files will be generated."
    )
    var output: String

    @Flag(name: .long, help: "Do not prompt if output would delete existing files.")
    var force = false

    // FIXME: Command to dump template files, option to provide template files

    @Argument var files: [String]

    public init() {}

    public func run() throws {
        // TODO: Debug log
        print("You gave us these files: \(files)")

        let fm = FileManager()
        var sources = [File]()

        for file in files {
            guard
                let contents = fm.contents(atPath: file),
                let source = String(data: contents, encoding: .utf8)
            else {
                print("Could not read file: \(file)")
                continue
            }

            sources.append(File(path: file, content: source))
        }

        do {
            let generatedFiles = try SwiftCodeGenerator(sources: sources).generate()
            let outputURL = URL(fileURLWithPath: output, isDirectory: true)

            if fm.fileExists(atPath: outputURL.path) {
                if !force {
                    print("Delete existing files at \(output)? (y/n) ", terminator: "")
                    let answer = readLine()
                    if answer?.lowercased() != "y" {
                        Self.exit(withError: ExecutionError.aborted)
                    }
                }
                try fm.removeItem(at: outputURL)
            }

            try fm.createDirectory(at: outputURL, withIntermediateDirectories: true)

            for file in generatedFiles {
                guard
                    fm.createFile(
                        atPath: outputURL.appendingPathComponent(file.path, isDirectory: false)
                            .path,
                        contents: file.content.data(using: .utf8)
                    )
                else {
                    throw ExecutionError.couldNotSaveFile
                }
            }
        } catch {
            print("\nError running codegen: \(error)")
        }
    }

    enum ExecutionError: Error {
        case aborted
        case couldNotSaveFile
    }
}
