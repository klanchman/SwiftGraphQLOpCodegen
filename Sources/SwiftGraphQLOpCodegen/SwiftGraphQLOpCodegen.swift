import ArgumentParser
import Foundation

public struct SwiftGraphQLOpCodegen: ParsableCommand {
    public static var configuration: CommandConfiguration = .init(
        commandName: "swift-graphql-op-codegen"
    )

    @Option(name: .shortAndLong, help: "The directory to output generated files into")
    var outdir: String

    @Argument var files: [String]

    public init() {}

    public func run() throws {
        // FIXME: Remove
        print("You gave us these files: \(files)")

        let fm = FileManager()

        for file in files {
            guard
                let contents = fm.contents(atPath: file),
                let source = String(data: contents, encoding: .utf8)
            else {
                print("Could not read file: \(file)")
                continue
            }

            do {
                let generatedFiles = try CodeGenerator(source: source).generate()

                guard !generatedFiles.isEmpty else {
                    continue
                }

                // FIXME: Output the files
                print("\nFile: \(file)")
                for generatedFile in generatedFiles {
                    print("\nSave filename: \(generatedFile.filename)\n")
                    print(generatedFile.contents)
                }
            } catch {
                print("\nError running codegen for file \(file): \(error)")
                continue
            }
        }
    }
}
