public struct Source: Equatable {
    public let body: String
    public let name: String

    public init(body: String, name: String = "GraphQL") {
        self.body = body
        self.name = name
    }

    public static func ==(lhs: Source, rhs: Source) -> Bool {
        return lhs.body == rhs.body && lhs.name == rhs.name
    }
}

extension Source: ExpressibleByStringLiteral {
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String

    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.init(body: value)
    }

    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.init(body: value)
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(body: value)
    }
}
