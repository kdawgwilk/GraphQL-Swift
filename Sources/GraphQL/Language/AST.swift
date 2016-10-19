
public struct Location {
    let start: String.Index
    let end: String.Index
    let startToken: Token
    let endToken: Token
    let source: Source?
}

enum TokenKind: String {
    case startOfFile = "<SOF>"
    case endOfFile = "<EOF>"
    case bang = "!"
    case dollar = "$"
    case parenLeft = "("
    case parenRight = ")"
    case spread = "..."
    case colon = ":"
    case equals = "="
    case at = "@"
    case bracketLeft = "["
    case bracketRight = "]"
    case braceLeft = "{"
    case pipe = "|"
    case braceRight = "}"
    case name = "Name"
    case int = "Int"
    case float = "Float"
    case string = "Comment"
}

struct Token {
    let kind: TokenKind
    let start: String.Index
    let end: String.Index
    let line: Int
    let column: Int
    let value: String?

    //    let prev: Token?
    //    let next: Token?
}

enum NodeType {
    case name
    case document
    case operationDefinition
    case variableDefinition
    case variable
    case selectionSet
    case field
    case argument
    case fragmentSpread
    case inlineFragment
    case fragmentDefinition
    case intValue
    case floatValue
    case stringValue
    case boolValue
    case enumValue
    case listValue
    case objectValue
    case objectField
    case directive
    case namedType
    case listType
    case nonNullType
    case schemaDefinition
    case operationTypeDefinition
    case scalarTypeDefinition
    case objectTypeDefinition
    case fieldDefinition
    case inputValueDefinition
    case interfaceTypeDefinition
    case unionTypeDefinition
    case enumTypeDefinition
    case enumValueDefinition
    case inputObjectTypedefinition
    case typeExtensionDefinition
    case directiveDefinition
}

protocol Node {
    var kind: NodeType { get }
    var loc: Location? { get }
}

struct Name: Node {
    let kind = NodeType.name
    let loc: Location?
    let value: String
}

struct Document {
    let kind = NodeType.document
    let loc: Location?
    let definitions: [Definition]
}

protocol Definition: Node {}

enum DefinitionType {
    case operationDefinition
    case fragmentDefinition
    case typeSystemDefinition // experimental non-spec addition.
}

struct OperationDefinition: Definition {
    let kind = DefinitionType.operationDefinition
    let loc: Location?
    let operation: OperationType
    let name: Name?
    let variableDefinitions: [VariableDefinition]?
    let directives: [Directive]?
    let selectionSet: SelectionSet
}

enum OperationType {
    case query
    case mutation
    // Note: subscription is an experimental non-spec addition.
    case subscription
}

struct VariableDefinition: Definition {
    let variable: Variable
    let inputType: InputType
    let defaultValue: Value?
    let location: Location?

    var type: NodeType = .variableDefinition
}




















