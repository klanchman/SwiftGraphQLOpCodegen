import Foundation
import GraphQL
import PathKit
import Stencil

class SwiftCodeGenerator {
    private let context: GraphQLContext
    private let singleFileMode: Bool
    private let protocolTemplate: File
    private let operationTemplate: File
    private let allOperationsTemplate: File

    init(
        sources: [File],
        singleFileMode: Bool,
        protocolTemplate: File?,
        operationTemplate: File?,
        allOperationsTemplate: File?
    ) throws {
        self.context = try GraphQLContext(sources: sources)
        self.singleFileMode = singleFileMode

        let bundledTemplates = try TemplateFiles()
        self.protocolTemplate = protocolTemplate ?? bundledTemplates.protocolTemplate
        self.operationTemplate = operationTemplate ?? bundledTemplates.operationTemplate
        self.allOperationsTemplate = allOperationsTemplate ?? bundledTemplates.allOperationsTemplate
    }

    func generate() throws -> [File] {
        let stencilEnv = Stencil.Environment()
        var files = [File]()

        if singleFileMode {
            var stencilOperations = [[String: Any]]()

            for (operationName, operation) in context.operations.sorted(by: { $0.key < $1.key }) {
                let mergedSource = try mergeFragments(operation: operation)

                stencilOperations.append([
                    "name": operationName,
                    "mergedSource": mergedSource,
                    "variables": try stencilVariablesContext(operation.definition),
                ])
            }

            let s = try stencilEnv.renderTemplate(
                string: allOperationsTemplate.content,
                context: ["operations": stencilOperations]
            )

            files.append(File(path: Path("APIOperations.swift"), content: s))
        } else {
            files.append(
                File(
                    path: "GraphQLOperation.swift",
                    content: try stencilEnv.renderTemplate(string: protocolTemplate.content)
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
                    string: operationTemplate.content,
                    context: [
                        "operation": [
                            "name": operationName,
                            "mergedSource": mergedSource,
                            "variables": stencilVariablesContext(operation.definition),
                        ]
                    ]
                )

                files.append(File(path: Path("\(operationName)\(operationType).swift"), content: s))
            }
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
