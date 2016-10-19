enum TokenKind {
    case endOfFile
    case bang
    case dollar
    case parenLeft
    case parenRight
    case spread
    case colon
    case equals
    case at
    case bracketLeft
    case bracketRight
    case braceLeft
    case pipe
    case braceRight
    case name
    case variable
    case int
    case float
    case string
}

struct Token {
    let kind: TokenKind
    let start: String.Index
    let end: String.Index
    let value: Any?

    init(kind: TokenKind, start: String.Index, end: String.Index, value: Any? = nil) {
        self.kind = kind
        self.start = start
        self.end = end
        self.value = value
    }
}
