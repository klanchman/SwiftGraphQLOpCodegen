import Foundation
import GraphQL

struct CodeGenerator {
    let source: String

    func generate() throws -> String? {
        let result = try GraphQL.parse(source: Source(body: source))

        var s = ""

        for def in result.definitions {
            // FIXME: Warn?
            guard let def = def as? OperationDefinition else {
                continue
            }

            // FIXME: Placeholder
            s += "Operation: \(def.name!.value) of kind \(def.operation)"
            try def.variableDefinitions.forEach {
                s += "\nVariable: \($0.variable.name.value) of type \(try dumpType(type: $0.type))"
            }

            s += "\n"
        }

        return s
    }

    private func dumpVariable(variable: VariableDefinition) throws -> String {
        try dumpType(type: variable.type)
    }

    private func dumpType(type: Type) throws -> String {
        if let type = type as? NonNullType {
            return "NonNull<\(try dumpType(type: type.type))>"
        } else if let type = type as? NamedType {
            return type.name.value
        } else if let type = type as? ListType {
            return "[\(try dumpType(type: type.type))]"
        } else {
            throw CodegenError.unsupportedType(String(describing: type))
        }
    }

    enum CodegenError: Error {
        case unsupportedType(String)
    }
}
