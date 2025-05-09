import Foundation
import GraphQL
import Stencil

class SwiftCodeGenerator {
    private let context: GraphQLContext

    init(
        sources: [File]
    ) throws {
        self.context = try GraphQLContext(sources: sources)
    }

    func generate() throws -> [File] {
        var files = [File]()

        let stencilEnv = Stencil.Environment()

        // FIXME: Allow passing in templates / template path
        let protocolTemplatePath = Bundle.module.path(
            forResource: "GraphQLOperation",
            ofType: "stencil",
            inDirectory: "Templates"
        )
        let protocolTemplateData = FileManager.default.contents(atPath: protocolTemplatePath!)
        let protocolTemplate = String(data: protocolTemplateData!, encoding: .utf8)!

        let operationTemplatePath = Bundle.module.path(
            forResource: "Operation",
            ofType: "stencil",
            inDirectory: "Templates"
        )
        let operationTemplateData = FileManager.default.contents(atPath: operationTemplatePath!)
        let operationTemplate = String(data: operationTemplateData!, encoding: .utf8)!

        files.append(
            .init(
                path: "GraphQLOperation.swift",
                content: try stencilEnv.renderTemplate(string: protocolTemplate)
            )
        )

        for (operationName, operation) in context.operations.sorted(by: { $0.key < $1.key }) {
            let mergedSource = try mergeFragments(operation: operation)
            let operationType =
                switch operation.definition.operation {
                case .mutation: "Mutation"
                case .query: "Query"
                case .subscription: "Subscription"
                }

            let s = try stencilEnv.renderTemplate(
                string: operationTemplate,
                context: [
                    "operation": [
                        "name": operationName,
                        "mergedSource": mergedSource,
                        "variables": stencilVariablesContext(operation.definition),
                    ]
                ]
            )

            files.append(File(path: "\(operationName)\(operationType).swift", content: s))
        }

        return files
    }

    private func stencilVariablesContext(
        _ operation: OperationDefinition
    ) throws -> [[String: Any]] {
        try operation.variableDefinitions.map { varDef in
            return [
                "name": varDef.variable.name.value,
                "swiftType": try renderSwiftType(varDef.type),
            ]
        }
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

    private func renderSwiftType(_ type: Type, isOptional: Bool = true) throws -> String {
        if let type = type as? NonNullType {
            return try renderSwiftType(type.type, isOptional: false)
        } else if let type = type as? NamedType {
            return "\(mapTypeName(type))\(isOptional ? "??" : "")"
        } else if let type = type as? ListType {
            return "[\(try renderSwiftType(type.type))]\(isOptional ? "??" : "")"
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
