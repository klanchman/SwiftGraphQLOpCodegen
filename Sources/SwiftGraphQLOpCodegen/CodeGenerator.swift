import Foundation
import GraphQL

class CodeGenerator {
    private let context: Context

    init(
        sources: [File]
    ) throws {
        self.context = try Context(sources: sources)
    }

    func generate() throws -> [File] {
        var files = [File]()

        for (operationName, operation) in context.operations {
            let mergedSource = try mergeFragments(operation: operation)
            let minifiedSource = Self.minify(mergedSource)

            let s = #"""
                struct \#(operationName) {
                    let name = "\#(operationName)"
                    let operation = "\#(minifiedSource)"
                    \#(try renderVariables(operation: operation.definition))
                }

                """#

            files.append(File(path: "\(operationName).swift", content: s))
        }

        return files
    }

    private static func minify(_ source: String) -> String {
        source.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
    }

    private func mergeFragments(operation: DefWrapper<OperationDefinition>) throws -> String {
        var source = try operation.scopedSource()
        var neededFragments = operation.fragmentReferences

        for fragmentName in operation.fragmentReferences {
            guard let fragment = context.fragments[fragmentName] else {
                throw CodegenError.unknownDefinition(fragmentName)
            }

            neededFragments.formUnion(try fragmentsReferencedBy(fragment: fragment))
        }

        for fragmentName in neededFragments {
            guard let fragment = context.fragments[fragmentName] else {
                throw CodegenError.unknownDefinition(fragmentName)
            }

            source += "\n\(try fragment.scopedSource())"
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
            return "\(type.name.value)\(isOptional ? "??" : "")"
        } else if let type = type as? ListType {
            return "[\(try renderType(type.type))]\(isOptional ? "??" : "")"
        } else {
            throw CodegenError.unsupportedType(String(describing: type))
        }
    }
}

extension CodeGenerator {
    enum CodegenError: Error {
        case unsupportedType(String)
        case unknownDefinition(String)
        case missingLocation
    }
}

private extension CodeGenerator {
    class Context {
        private(set) var fragments = [String: DefWrapper<FragmentDefinition>]()
        private(set) var operations = [String: DefWrapper<OperationDefinition>]()
        let sources: [File]

        init(
            sources: [File]
        ) throws {
            self.sources = sources

            for source in sources {
                let parsed = try GraphQL.parse(source: Source(body: source.content))

                for definition in parsed.definitions {
                    if let definition = definition as? OperationDefinition {
                        let op = DefWrapper(definition: definition, source: source.content)

                        guard let name = definition.name?.value else {
                            print("Warning: Ignoring unnamed operation in file \(source.path)")
                            continue
                        }

                        operations[name] = op
                    } else if let definition = definition as? FragmentDefinition {
                        let op = DefWrapper(definition: definition, source: source.content)
                        fragments[op.definition.name.value] = op
                    } else {
                        // FIXME: Verbose
                        print(
                            "Ignoring unknown definition of type \(definition.kind) in \(source.path)"
                        )
                    }
                }
            }
        }
    }

    class DefWrapper<Def: NamedDefWithSelSet> {
        let definition: Def

        private let fullSource: String
        private(set) var fragmentReferences = Set<String>()

        init(
            definition: Def,
            source: String
        ) {
            self.definition = definition
            fullSource = source

            for selection in definition.selectionSet.selections {
                if let selection = selection as? FragmentSpread {
                    fragmentReferences.insert(selection.name.value)
                } else if let selection = selection as? InlineFragment {
                    fragmentReferences.formUnion(Self.fragmentSpreads(in: selection.selectionSet))
                } else if let selection = selection as? Field,
                    let selectionSet = selection.selectionSet
                {
                    fragmentReferences.formUnion(Self.fragmentSpreads(in: selectionSet))
                }
            }

            // FIXME: Debug
            print(
                "\(definition.kind) \(String(describing: definition.internalName?.value)) spreads fragments \(fragmentReferences)"
            )
        }

        func scopedSource() throws -> String {
            let s = fullSource
            guard let loc = definition.loc else { throw CodegenError.missingLocation }
            let start = s.index(s.startIndex, offsetBy: loc.startToken.start)
            let end = s.index(s.startIndex, offsetBy: Self.recurseToEnd(of: loc.startToken))

            return String(s[start..<end])
        }

        private static func fragmentSpreads(in selectionSet: SelectionSet) -> Set<String> {
            let selections = selectionSet.selections

            var spreads = Set<String>()

            for selection in selections {
                if let selection = selection as? Field, let selectionSet = selection.selectionSet {
                    spreads.formUnion(fragmentSpreads(in: selectionSet))
                } else if let selection = selection as? InlineFragment {
                    spreads.formUnion(fragmentSpreads(in: selection.selectionSet))
                } else if let selection = selection as? FragmentSpread {
                    spreads.insert(selection.name.value)
                }
            }

            return spreads
        }

        private static func recurseToEnd(of token: Token, braceDepth: Int = 0) -> Int {
            guard let next = token.next else {
                // FIXME: Is this right?
                return token.end
            }

            if token.kind == .openingBrace {
                return recurseToEnd(of: next, braceDepth: braceDepth + 1)
            } else if token.kind == .closingBrace {
                let braceCount = braceDepth - 1
                return braceCount == 0 ? token.end : recurseToEnd(of: next, braceDepth: braceCount)
            } else {
                return recurseToEnd(of: next, braceDepth: braceDepth)
            }
        }
    }
}

protocol NamedDefWithSelSet: Definition {
    var selectionSet: SelectionSet { get }
    var internalName: Name? { get }
    var kind: Kind { get }
}

extension FragmentDefinition: NamedDefWithSelSet {
    var internalName: Name? { name }
}

extension OperationDefinition: NamedDefWithSelSet {
    var internalName: Name? { name }
}
