final class Parser {
    let lexer: (String.Index?) throws -> Token
    let source: Source
    let options: ParserOptions
    var previousEnd: String.Index
    var currentToken: Token

    static func parse(source: Source, options: ParserOptions = []) throws -> AbstractSyntaxTree {
        let lexer = Lexer.functionFor(source: source)
        let parser = Parser(lexer: lexer, source: source, options: options, previousEnd: source.body.startIndex, token: try lexer(nil))
        return try parser.parse()
    }

    init(lexer: @escaping (String.Index?) throws -> Token,
        source: Source,
        options: ParserOptions,
        previousEnd: String.Index,
        token: Token) {
            self.lexer = lexer
            self.source = source
            self.options = options
            self.previousEnd = previousEnd
            self.currentToken = token
    }

    func parse() throws -> AbstractSyntaxTree {
        let start = currentToken.start
        var definitions: [Definition] = []

        repeat {

            switch currentToken.kind {
            case .braceLeft:
                definitions.append(try parseShorthandQueryDefinition())
            case .name:
                let name = try peekAtValueOfName(token: currentToken)
                switch name {
                case query:
                    definitions.append(try parseOperationDefinition(of: .query))
                case mutation:
                    definitions.append(try parseOperationDefinition(of: .mutation))
                case fragment:
                    definitions.append(try parseFragmentDefinition())
                default:
                    throw unexpectedTokenError
                }
            default:
                throw unexpectedTokenError
            }

        } while try !skipping(kind: .endOfFile)

        return AbstractSyntaxTree(definitions: definitions, location: locateWith(start: start))
    }

    /// If the next token is of the given kind, `skipping` skips over it and returns `true`.
    /// If the next token is different, `skipping` doesn't move the parser and returns `false`.
    ///
    /// The naming is in favor of readability: `try skipping(.Foo)` conveys the behavior well.
    func skipping(kind: TokenKind) throws -> Bool {
        let match = currentToken.kind == kind
        if (match) {
            try advance()
        }
        return match
    }

    func advance() throws {
        previousEnd = currentToken.end
        currentToken = try lexer(previousEnd)
    }

    func currentToken(is kind: TokenKind) -> Bool {
        return currentToken.kind == kind
    }

    func parseShorthandQueryDefinition() throws -> OperationDefinition {
        let start = currentToken.start

        return OperationDefinition(
            operationType: .query,
            name: nil,
            variableDefinitions: [],
            directives: [],
            selectionSet: try parseSelectionSet(),
            location: locateWith(start: start))
    }

    func parseOperationDefinition(of type: OperationType) throws -> OperationDefinition {
        let start = currentToken.start

        try advance()
        return OperationDefinition(
            operationType: type,
            name: try parseValidName(),
            variableDefinitions: try parseVariableDefinitions(),
            directives: try parseDirectives(),
            selectionSet: try parseSelectionSet(),
            location: locateWith(start: start))
    }

    func parseVariableDefinitions() throws -> [VariableDefinition] {
        return currentToken(is: .parenLeft)
        ? try parseOneOrMoreBetweenDelimiters(left: .parenLeft, function: parseVariableDefinition, right: .parenRight)
        : []
    }

    func parseVariableDefinition() throws -> VariableDefinition {
        let start = currentToken.start

        return VariableDefinition(
            variable: try parseVariable(),
            inputType: try { let _ = try expect(kind: .colon); return try parseType() }(),
            defaultValue: try skipping(kind: .equals) ? try parseValue(isConst: true) : nil,
            location: locateWith(start: start))
    }

    func parseType() throws -> InputType {
        let start = currentToken.start

        var type: InputType
        if try skipping(kind: .bracketLeft) {
            type = try parseType()
            let _ = try expect(kind: .bracketRight)
            type = ListType(inputType: type, location: locateWith(start: start))
        } else {
            type = try parseNamedType()
        }
        if try skipping(kind: .bang) {
            return NonNullType(inputType: type, location: locateWith(start: start))
        } else {
            return type
        }
    }

    func parseNamedType() throws -> NamedType {
        let start = currentToken.start
        let token = try expect(kind: .name)
        return NamedType(value: try peekAtValueOfName(token: token), location: locateWith(start: start))
    }

    func parseFragmentDefinition() throws -> FragmentDefinition {
        let start = currentToken.start
        let _ = try expect(keyword: fragment)
        return FragmentDefinition(
            name: try parseFragmentName(),
            typeCondition: try parseTypeCondition(),
            directives: try parseDirectives(),
            selectionSet: try parseSelectionSet(),
            location: locateWith(start: start))
    }

    func parseFragmentName() throws -> ValidName {
        let name = try parseValidName()
        guard name.string != on else { throw unexpectedTokenError }
        return name
    }

    func parseTypeCondition() throws -> NamedType {
        let _ = try expect(keyword: on)
        return try parseNamedType()
    }

    func expect(keyword: String) throws -> Token {
        guard currentToken.kind == .name,
            let value = currentToken.value as? String, value == keyword else {
            throw ParserError.unexpectedToken(source: source, position: previousEnd, description: "Expected \(keyword), found \(currentToken)")
        }
        let token = currentToken
        try advance()
        return token
    }

    func parseValidName() throws -> ValidName {
        let start = currentToken.start
        let token = try expect(kind: .name)
        return ValidName(string: try peekAtValueOfName(token: token), location: locateWith(start: start))
    }

    func expect(kind: TokenKind) throws -> Token {
        if currentToken.kind == kind {
            let token = currentToken
            try advance()
            return token
        } else {
            throw ParserError.unexpectedToken(source: source, position: previousEnd, description: "Expected \(kind), found \(currentToken.kind)")
        }
    }

    func parseSelectionSet() throws -> SelectionSet {
        let start = currentToken.start
        return SelectionSet(
            selections: try parseOneOrMoreBetweenDelimiters(left: .braceLeft, function: parseSelection, right: .braceRight),
            location: locateWith(start: start))
    }

    func parseSelection() throws -> Selection {
        return currentToken(is: .spread) ? try parseFragment() : try parseField()
    }

    func parseFragment() throws -> Fragment {
        let start = currentToken.start
        let _ = try expect(kind: .spread)

        if currentToken(is: .name) {

            switch try peekAtValueOfName(token: currentToken) {
            case on:
                return InlineFragment(
                    typeCondition: try parseTypeCondition(),
                    directives: try parseDirectives(),
                    selectionSet: try parseSelectionSet(),
                    location: locateWith(start: start))
            default:
                return FragmentSpread(
                    name: try parseFragmentName(),
                    directives: try parseDirectives(),
                    location: locateWith(start: start))
            }

        } else {
            return InlineFragment(
                typeCondition: nil,
                directives: try parseDirectives(),
                selectionSet: try parseSelectionSet(),
                location: locateWith(start: start))
        }
    }

    func parseField() throws -> Field {
        let start = currentToken.start

        let nameOrAlias = try parseValidName()

        var alias: ValidName?
        var name: ValidName
        if try skipping(kind: .colon) {
            alias = nameOrAlias
            name = try parseValidName()
        } else {
            alias = nil
            name = nameOrAlias
        }

        return Field(
            alias: alias,
            name: name,
            arguments: try parseArguments(),
            directives: try parseDirectives(),
            selectionSet: currentToken(is: .braceLeft) ? try parseSelectionSet() : nil,
            location: locateWith(start: start))
    }

    func parseArguments() throws -> [Argument] {
        return currentToken(is: .parenLeft)
            ? try parseOneOrMoreBetweenDelimiters(left: .parenLeft, function: parseArgument, right: .parenRight)
            : []
    }

    func parseArgument() throws -> Argument {
        let start = currentToken.start
        return Argument(
            name: try parseValidName(),
            value: try parseArgumentValue(),
            location: locateWith(start: start))
    }

    func parseArgumentValue() throws -> Value {
        let _ = try expect(kind: .colon)
        return try parseValue(isConst: false)
    }

    func parseDirectives() throws -> [Directive] {
        var directives: [Directive] = []
        while currentToken(is: .at) {
            directives.append(try parseDirective())
        }
        return directives
    }

    func parseDirective() throws -> Directive {
        let start = currentToken.start
        let _ = try expect(kind: .at)
        return Directive(
            name: try parseValidName(),
            arguments: try parseArguments(),
            location: locateWith(start: start))
    }

    func parseValue(isConst: Bool) throws -> Value {
        switch currentToken.kind {
        case .bracketLeft:
            return try parseArray(isConst: isConst)
        case .braceLeft:
            return try parseInputObject(isConst: isConst)
        case .int:
            return try parseIntValue()
        case .float:
            return try parseFloatValue()
        case .string:
            return try parseStringValue()
        case .name:
            return try parseBoolOrEnumValue()
        case .dollar:
            if (!isConst) {
                return try parseVariable()
            }
        default: break
        }
        throw unexpectedTokenError
    }

    func parseArray(isConst: Bool) throws -> ListValue {
        let start = currentToken.start
        let parseFunction = isConst ? parseConstValue : parseVariableValue
        return ListValue(
            values: try parseZeroOrMoreBetweenDelimiters(left: .bracketLeft, function: parseFunction, right: .bracketRight),
            location: locateWith(start: start))
    }

    func parseIntValue() throws -> IntValue {
        let token = currentToken
        guard let value = token.value as? Int else { throw unexpectedTokenError }
        try advance()
        return IntValue(value: value, location: locateWith(start: token.start))
    }

    func parseFloatValue() throws -> FloatValue {
        let token = currentToken
        guard let value = token.value as? Float else { throw unexpectedTokenError }
        try advance()
        return FloatValue(value: value, location: locateWith(start: token.start))
    }

    func parseStringValue() throws -> StringValue {
        let token = currentToken
        guard let value = token.value as? String else { throw unexpectedTokenError }
        try advance()
        return StringValue(value: value, location: locateWith(start: token.start))
    }

    func parseVariable() throws -> Variable {
        let start = currentToken.start
        let _ = try expect(kind: .dollar)
        return Variable(name: try parseValidName(), location: locateWith(start: start))
    }

    func parseBoolOrEnumValue() throws -> Value {
        let start = currentToken.start
        switch try parseValueOfNameToken() {
        case "true": return BoolValue(value: true, location: locateWith(start: start))
        case "false": return BoolValue(value: false, location: locateWith(start: start))
        case let string: return EnumValue(value: string, location: locateWith(start: start))
        }
    }

    func parseInputObject(isConst: Bool) throws -> InputObjectValue {
        let start = currentToken.start
        let _ = try expect(kind: .braceLeft)
        var fields: [InputObjectField] = []
        // This should be IdentitySet<ValidName>
        var fieldNames: [ValidName] = []
        while try !skipping(kind: .braceRight) {
            fields.append(try parseInputObjectField(isConst: isConst, existingFieldNames: &fieldNames))
        }
        return InputObjectValue(fields: fields, location: locateWith(start: start))
    }

    func parseInputObjectField(isConst: Bool, existingFieldNames: inout [ValidName]) throws -> InputObjectField {
        let start = currentToken.start
        let name = try parseValidName()
        guard !(existingFieldNames.contains { $0.string == name.string }) else {
            throw ParserError.duplicateInputObjectField(source: source, position: previousEnd, description: "Duplicate input object field \(name.string)")
        }
        existingFieldNames.append(name)

        return InputObjectField(
            name: name,
            value: try parseObjectFieldValue(isConst: isConst),
            location: locateWith(start: start))
    }

    func parseObjectFieldValue(isConst: Bool) throws -> Value {
        let _ = try expect(kind: .colon)
        return try parseValue(isConst: isConst)
    }

    func parseConstValue() throws -> Value {
        return try parseValue(isConst: true)
    }

    func parseVariableValue() throws -> Value {
        return try parseValue(isConst: false)
    }

    func parseValueOfNameToken() throws -> String {
        let name = try peekAtValueOfName(token: currentToken)
        try advance()
        return name
    }

    func peekAtValueOfName(token: Token) throws -> String {
        guard token.kind == .name else { throw unexpectedTokenError }
        guard let name = token.value as? String else { throw unexpectedTokenError }
        return name
    }

    var unexpectedTokenError: ParserError {
        return ParserError.unexpectedToken(source: source, position: previousEnd, description: "Unexpected \(currentToken)")
    }

    func parseZeroOrMoreBetweenDelimiters<T>(left: TokenKind, function: () throws -> T, right: TokenKind) throws -> [T] {
        let _ = try expect(kind: left)
        var nodes: [T] = []
        while try !skipping(kind: right) {
            nodes.append(try function())
        }
        return nodes
    }

    func parseOneOrMoreBetweenDelimiters<T>(left: TokenKind, function: () throws -> T, right: TokenKind) throws -> [T] {
        let _ = try expect(kind: left)
        var nodes: [T] = [try function()]
        while try !skipping(kind: right) {
            nodes.append(try function())
        }
        return nodes
    }

    func locateWith(start: String.Index) -> Location? {
        guard !options.contains(ParserOptions.NoLocation) else { return nil }

        let source: Source? = options.contains(ParserOptions.NoLocation) ? nil : self.source
        return Location(start: start, end: previousEnd, source: source)
    }
}

enum ParserError: Error {
    case unexpectedToken(source: Source, position: String.Index, description: String)
    // This has been moved to a rule
    case duplicateInputObjectField(source: Source, position: String.Index, description: String)
}

struct ParserOptions: OptionSet {
    let rawValue: UInt
    static let NoLocation = ParserOptions(rawValue: 1 << 0)
    static let NoSource = ParserOptions(rawValue: 1 << 1)
}

private let query = "query"
private let mutation = "mutation"
private let fragment = "fragment"
private let on = "on"
