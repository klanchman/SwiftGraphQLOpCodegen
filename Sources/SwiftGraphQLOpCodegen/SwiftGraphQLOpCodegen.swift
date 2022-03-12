import ArgumentParser
import Foundation

public struct SwiftGraphQLOpCodegen: ParsableCommand {
    public static var configuration: CommandConfiguration = .init(
        commandName: "swift-graphql-op-codegen"
    )

    @Option(name: .shortAndLong, help: "The path of the file to output")
    var output: String

    @Argument var files: [String]

    public init() {}

    public func run() throws {
        // FIXME: Remove
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
            let generatedFiles = try CodeGenerator(sources: sources).generate()
            let content = generatedFiles.reduce(into: "") { partialResult, next in
                partialResult += "\n\(next.content)"
            }

            guard
                fm.createFile(
                    atPath: output,
                    contents: content.data(using: .utf8)
                )
            else {
                throw ExecutionError.couldNotSaveFile
            }
        } catch {
            print("\nError running codegen: \(error)")
        }
    }

    enum ExecutionError: Error {
        case couldNotSaveFile
    }
}
