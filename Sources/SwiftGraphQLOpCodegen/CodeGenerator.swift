import Foundation
import GraphQL

// FIXME: Handle fragments in source
struct CodeGenerator {
    let source: String

    private var minifiedSource: String {
        source.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
    }

    func generate() throws -> [GeneratedFile] {
        let result = try GraphQL.parse(source: Source(body: source))

        var files = [GeneratedFile]()

        for def in result.definitions {
            // FIXME: Verbose?
            guard let def = def as? OperationDefinition else {
                continue
            }

            // FIXME: Warn w/ file path
            guard let operationName = def.name?.value else {
                print("Ignoring unnamed operation")
                continue
            }

            let s = #"""
                struct \#(operationName) {
                    let name = "\#(operationName)"
                    let operation = "\#(minifiedSource)"
                    \#(try renderVariables(operation: def))
                }

                """#

            files.append(GeneratedFile(filename: "\(operationName).swift", contents: s))
        }

        return files
    }

    private func renderVariables(operation: OperationDefinition) throws -> String {
        guard !operation.variableDefinitions.isEmpty else { return "" }

        // FIXME: Handle indentation better
        return """
            let variables: Variables

                struct Variables: Encodable {
                    \(try operation.variableDefinitions
                        .map { try renderVariable($0) }
                        .joined(separator: "\n        "))
                }
            """
    }

    private func renderVariable(_ variable: VariableDefinition) throws -> String {
        "let \(variable.variable.name.value): \(try renderType(variable.type))"
    }

    private func renderType(_ type: Type, isOptional: Bool = true) throws -> String {
        if let type = type as? NonNullType {
            return try renderType(type.type, isOptional: false)
        } else if let type = type as? NamedType {
            return "\(type.name.value)\(isOptional ? "??" : "")"
        } else if let type = type as? ListType {
            return "[\(try renderType(type.type))]"
        } else {
            throw CodegenError.unsupportedType(String(describing: type))
        }
    }

    enum CodegenError: Error {
        case unsupportedType(String)
    }

    struct GeneratedFile {
        let filename: String
        let contents: String
    }
}
