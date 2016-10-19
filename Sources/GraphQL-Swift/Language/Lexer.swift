enum LexerErrorCode: Int {
    case unexpectedCharacter
    case invalidNumber
    case unterminatedString
    case badCharacterEscapeSequence
}

struct LexerError: Error {
    let code: LexerErrorCode
    let source: Source
    let position: String.Index
}

struct Lexer {
    static func functionFor(source: Source) -> ((String.Index?) throws -> Token) {
        var previousPosition = source.body.startIndex
        return { position in
            let token = try read(source: source, position: position ?? previousPosition)
            previousPosition = token.end
            return token
        }
    }

    static func read(source: Source, position: String.Index) throws -> Token {
        let body = source.body

        let position = positionAfterWhitespace(body: body, position: position)

        if position >= body.endIndex {
            return Token(kind: .endOfFile, start: position, end: position)
        }

        switch body[position] {

        case "!": return Token(kind: .bang, start: position, end: body.index(after: position))
        case "$": return Token(kind: .dollar, start: position, end: body.index(after: position))
        case "(": return Token(kind: .parenLeft, start: position, end: body.index(after: position))
        case ")": return Token(kind: .parenRight, start: position, end: body.index(after: position))
        case "." where body[body.index(after: position)] == "." && body[body.index(position, offsetBy: 3)] == ".":
            return Token(kind: .spread, start: position, end: body.index(position, offsetBy: 3))
        case ":": return Token(kind: .colon, start: position, end: body.index(after: position))
        case "=": return Token(kind: .equals, start: position, end: body.index(after: position))
        case "@": return Token(kind: .at, start: position, end: body.index(after: position))
        case "[": return Token(kind: .bracketLeft, start: position, end: body.index(after: position))
        case "]": return Token(kind: .bracketRight, start: position, end: body.index(after: position))
        case "{": return Token(kind: .braceLeft, start: position, end: body.index(after: position))
        case "|": return Token(kind: .pipe, start: position, end: body.index(after: position))
        case "}": return Token(kind: .braceRight, start: position, end: body.index(after: position))

        case "A"..."Z", "_", "a"..."z": return readName(source: source, position: position)
        case "-", "0"..."9":
            return try readNumber(source: source, position: position)

        case "\"":
            return try readString(source: source, position: position)

        default: throw LexerError(code: .unexpectedCharacter, source: source, position: position)

        }
    }

    static func readName(source: Source, position start: String.Index) -> Token {
        let body = source.body
        var end = start
        let characters = body[start..<body.endIndex].characters

        for character in characters.makeIterator() {
            guard character.isValidNameCharacter else { break }
            end = characters.index(after: end)
        }

        return Token(kind: .name, start: start, end: end, value: body[start..<end])
    }

    static func readNumber(source: Source, position start: String.Index) throws -> Token {
        let body = source.body
        var end = start
        let characters = body[start..<body.endIndex].characters
        var iterator = characters.makeIterator()
        var lastCharacterInvalid = false
        var isFloat = false
        let nextCharacter: () -> Character? = {
            let next = iterator.next()
            guard let _ = next else { return next }
            end = characters.index(after: end)
            return next
        }

        var character = nextCharacter()

        let readDigits: () -> () = {
            repeat {
                character = nextCharacter()
                guard let tested = character, case "0"..."9" = tested else {
                    if end < body.endIndex {
                        lastCharacterInvalid = true
                    }
                    break
                }
            } while true
        }

        if character == "-" {
            character = nextCharacter()
        }

        if character == "0" {
            character = nextCharacter()
        } else if let tested = character, case "1"..."9" = tested {
            readDigits()
        } else {
            throw LexerError(code: .invalidNumber, source: source, position: end)
        }

        if character == "." {
            isFloat = true
            lastCharacterInvalid = false
            character = nextCharacter()

            if let tested = character, case "0"..."9" = tested {
                readDigits()
            } else {
                throw LexerError(code: .invalidNumber, source: source, position: end)
            }

            if character == "e" {
                lastCharacterInvalid = false
                character = nextCharacter()

                if character == "-" {
                    character = nextCharacter()
                }
                if let tested = character, case "0"..."9" = tested {
                    readDigits()
                } else {
                    throw LexerError(code: .invalidNumber, source: source, position: end)
                }
            }
        }

        if lastCharacterInvalid { end = characters.index(before: end) }

        let value = body[start..<end]
        // IMPROVEMENT: Raise error if the number cannot be converted
        // IMPROVEMENT: Add support for Double instead of Float
        return Token(kind: isFloat ? .float : .int, start: start, end: end, value: isFloat ? Float(value)! : Int(value)!)
    }

    static func readString(source: Source, position start: String.Index) throws -> Token {
        let body = source.body
        let characters = body[body.index(after: start)..<body.endIndex].characters
        var alreadyProcessed = start
        var end = start
        var value = ""
        var escapingCharacters = false
        var charactersToSkip = 0

        lexing: for character in characters.makeIterator() {
            end = characters.index(after: end)

            if (charactersToSkip > 0) {
                charactersToSkip -= 1
                continue
            }

            if (!escapingCharacters) {

                switch character {
                case "\"", "\n", "\r", "\u{2028}", "\u{2029}": break lexing
                case "\\":
                    value += body[body.index(after: alreadyProcessed)..<end]
                    alreadyProcessed = body.index(before: end)
                    escapingCharacters = true
                default: continue
                }

            } else {
                switch character {
                case "\"": value += "\""
                case "/": value += "/"
                case "\\": value += "\\"
                case "b": value += "\\b"
                case "f": value += "\\f"
                case "n": value += "\\n"
                case "r": value += "\\r"
                case "t": value += "\\t"
                case "u":

                    charactersToSkip = 4

                    guard body.endIndex > body.index(end, offsetBy: 3) else {
                        throw LexerError(code: .badCharacterEscapeSequence, source: source, position: end)
                    }

                    let characterCode = Int(body[body.index(after: end)...body.index(end, offsetBy: 4)], radix: 16)

                    if let characterCode = characterCode {
                        var unicodeCharacter = ""
                        UnicodeScalar(characterCode)?.write(to: &unicodeCharacter)
                        value += unicodeCharacter

                        alreadyProcessed = characters.index(alreadyProcessed, offsetBy: 4)
                    } else {
                        throw LexerError(code: .badCharacterEscapeSequence, source: source, position: end)
                    }

                default:
                    throw LexerError(code: .badCharacterEscapeSequence, source: source, position: end)
                }

                alreadyProcessed = characters.index(alreadyProcessed, offsetBy: 2)
                escapingCharacters = false
            }
        }

        guard body[end] == "\"" && end > start else {
            throw LexerError(code: .unterminatedString, source: source, position: end)
        }

        value += body[characters.index(after: alreadyProcessed)..<end]
        return Token(kind: .string, start: start, end: characters.index(after: end), value: value)
    }

    static func positionAfterWhitespace(body: String, position start: String.Index) -> String.Index {
        let characters = body[start..<body.endIndex].characters
        var position = start
        var insideComment = false

        search: for character in characters.makeIterator() {
            if (!insideComment) {
                switch character {
                case " ", ",", "\t"..."\r", "\u{2028}", "\u{2029}" : position = characters.index(after: position)
                case "#": insideComment = true; position = characters.index(after: position)
                default: break search
                }
            } else {
                position = characters.index(after: position)
                switch character {
                case "\n", "\r", "\u{2028}", "\u{2029}": insideComment = false
                default: continue
                }
            }
        }

        return position
    }
}



//func + (left: String.CharacterView.Index, right: Int) -> String.CharacterView.Index {
//    return left.advancedBy(right)
//}
//
//func - (left: String.CharacterView.Index, right: Int) -> String.CharacterView.Index {
//    return left.advancedBy(-right)
//}

extension Character {
    var isValidNameCharacter: Bool {
        get {
            switch self {
            case "A"..."Z", "_", "a"..."z", "0"..."9": return true
            default: return false
            }
        }
    }
}
