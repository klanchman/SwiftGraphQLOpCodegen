import Foundation
import GraphQL

class SwiftCodeGenerator {
    private let context: GraphQLContext

    init(
        sources: [File]
    ) throws {
        self.context = try GraphQLContext(sources: sources)
    }

    func generate() throws -> [File] {
        var files = [File]()

        for (operationName, operation) in context.operations.sorted(by: { $0.key < $1.key }) {
            let mergedSource = try mergeFragments(operation: operation)

            let s = #"""
                struct \#(operationName): Encodable {
                    let operationName = "\#(operationName)"
                    let query = "\#(mergedSource)"
                    \#(try renderVariables(operation: operation.definition))
                }

                """#

            files.append(File(path: "\(operationName).swift", content: s))
        }

        return files
    }

    private func mergeFragments(operation: DefWrapper<OperationDefinition>) throws -> String {
        var source = try DefinitionCodeGenerator.minify(operation.definition)
        var neededFragments = operation.fragmentReferences

        for fragmentName in operation.fragmentReferences {
            guard let fragment = context.fragments[fragmentName] else {
                throw CodegenError.unknownDefinition(fragmentName)
            }

            neededFragments.formUnion(try fragmentsReferencedBy(fragment: fragment))
        }

        for fragmentName in neededFragments.sorted(by: <) {
            guard let fragment = context.fragments[fragmentName] else {
                throw CodegenError.unknownDefinition(fragmentName)
            }

            source += try DefinitionCodeGenerator.minify(fragment.definition)
        }

        return source
    }

    private func fragmentsReferencedBy(
        fragment: DefWrapper<FragmentDefinition>
    ) throws -> Set<String> {
        var referencedFragments = fragment.fragmentReferences

        for fragmentName in fragment.fragmentReferences {
            guard let nestedFragment = context.fragments[fragmentName] else {
                throw CodegenError.unknownDefinition(fragmentName)
            }

            referencedFragments.formUnion(try fragmentsReferencedBy(fragment: nestedFragment))
        }

        return referencedFragments
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
            return "\(mapTypeName(type))\(isOptional ? "??" : "")"
        } else if let type = type as? ListType {
            return "[\(try renderType(type.type))]\(isOptional ? "??" : "")"
        } else {
            throw CodegenError.unsupportedType(String(describing: type))
        }
    }

    private func mapTypeName(_ type: NamedType) -> String {
        switch type.name.value {
        case "Boolean":
            return "Bool"
        default:
            return type.name.value
        }
    }
}

extension SwiftCodeGenerator {
    enum CodegenError: Error {
        case unsupportedType(String)
        case unknownDefinition(String)
        case missingLocation
    }
}
