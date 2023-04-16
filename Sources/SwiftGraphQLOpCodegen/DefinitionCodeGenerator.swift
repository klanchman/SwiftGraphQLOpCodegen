import Foundation
import GraphQL

enum DefinitionCodeGenerator {
    static func minify(_ definition: Definition) throws -> String {
        switch definition {
        case let definition as FragmentDefinition:
            return
                "fragment \(definition.name.value) on \(definition.typeCondition.name.value)\(try renderSelectionSet(definition.selectionSet))"
        case let definition as OperationDefinition:
            let vars = try definition.variableDefinitions.map(renderVariableDefinition).joined(
                separator: ","
            )

            return
                "\(definition.operation.rawValue) \(definition.name?.value ?? "")(\(vars))\(try renderSelectionSet(definition.selectionSet))"
        default:
            throw CodegenError.unexpectedDefinition(definition)
        }
    }
}

extension DefinitionCodeGenerator {
    enum CodegenError: Error {
        case notImplemented(String)
        case unexpectedDefinition(Definition)
        case unexpectedType(Type)
        case unexpectedSelection(Selection)
        case unexpectedValue(Value)
    }
}

extension DefinitionCodeGenerator {
    private static func renderVariableDefinition(
        _ variableDefinition: VariableDefinition
    ) throws -> String {
        return
            "$\(variableDefinition.variable.name.value):\(try renderType(variableDefinition.type))"
    }

    private static func renderType(_ type: Type) throws -> String {
        switch type {
        case let t as NonNullType:
            return "\(try renderType(t.type))!"
        case let t as NamedType:
            return t.name.value
        case let t as ListType:
            return "[\(try renderType(t.type))]"
        default:
            throw CodegenError.unexpectedType(type)
        }
    }

    private static func renderSelectionSet(_ selectionSet: SelectionSet) throws -> String {
        var fields = [String]()

        for s in selectionSet.selections {
            switch s {
            case let s as Field:
                fields.append(try renderField(s))
            case let s as FragmentSpread:
                fields.append("...\(s.name.value)\(try s.directives.map(renderDirective).joined())")
            case let s as InlineFragment:
                guard let typeCondition = s.typeCondition else {
                    // TODO: Implement
                    throw CodegenError.notImplemented(
                        "Inline fragments without an 'on' clause are not implemented"
                    )
                }

                fields.append(
                    "...on \(typeCondition.name.value)\(try s.directives.map(renderDirective).joined())\(try renderSelectionSet(s.selectionSet))"
                )
            default:
                throw CodegenError.unexpectedSelection(s)
            }
        }

        return "{\(fields.joined(separator: " "))}"
    }

    private static func renderField(_ field: Field) throws -> String {
        var str = ""

        if let alias = field.alias {
            str += "\(alias.value):"
        }

        str += field.name.value

        if !field.arguments.isEmpty {
            str += "(\(try field.arguments.map(renderArgument).joined(separator: ",")))"
        }

        if !field.directives.isEmpty {
            str += try field.directives.map(renderDirective).joined()
        }

        if let selectionSet = field.selectionSet {
            str += try renderSelectionSet(selectionSet)
        }

        return str
    }

    private static func renderDirective(_ directive: Directive) throws -> String {
        var str = "@\(directive.name.value)"

        if !directive.arguments.isEmpty {
            str += "(\(try directive.arguments.map(renderArgument).joined(separator: ",")))"
        }

        return str
    }

    private static func renderArgument(_ argument: Argument) throws -> String {
        return "\(argument.name.value):\(try renderValue(argument.value))"
    }

    private static func renderValue(_ value: Value) throws -> String {
        switch value {
        case let value as Variable:
            return "$\(value.name.value)"
        case let value as IntValue:
            return value.value
        case let value as FloatValue:
            return value.value
        case let value as StringValue:
            return value.value
        case let value as BooleanValue:
            return value.value ? "true" : "false"
        case _ as NullValue:
            return "null"
        case let value as EnumValue:
            return value.value
        case let value as ListValue:
            return "[\(try value.values.map(renderValue).joined(separator: ","))]"
        case _ as ObjectValue:
            // TODO: Implement
            throw CodegenError.notImplemented("Object values are not implemented")
        default:
            throw CodegenError.unexpectedValue(value)
        }
    }

}
