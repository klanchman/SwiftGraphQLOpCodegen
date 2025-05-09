import Foundation
import GraphQL

class GraphQLContext {
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
                    let op = DefWrapper(definition: definition)

                    guard let name = definition.name?.value else {
                        print("Warning: Ignoring unnamed operation in file \(source.path)")
                        continue
                    }

                    operations[name] = op
                } else if let definition = definition as? FragmentDefinition {
                    let op = DefWrapper(definition: definition)
                    fragments[op.definition.name.value] = op
                } else {
                    // TODO: Verbose log
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

    private(set) var fragmentReferences = Set<String>()

    init(
        definition: Def
    ) {
        self.definition = definition

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

        // TODO: Debug log
        print(
            "\(definition.kind) \(String(describing: definition.internalName?.value)) spreads fragments \(fragmentReferences)"
        )
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
}

// Below stuff lets us wrap both operation and fragment definitions in a DefWrapper.
// `internalName` is needed because a fragment's `name` isn't optional, but an operation's is.

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
