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
                guard let code = try CodeGenerator(source: source).generate(), !code.isEmpty else {
                    continue
                }

                print("\nFile: \(file)\n\(code)")
            } catch {
                print("\nError running codegen for file \(file): \(error)")
                continue
            }
        }
    }
}
