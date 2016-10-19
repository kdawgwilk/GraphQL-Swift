public protocol Identifiable {
    var identifier: String { get }
}

public struct IdentitySet<Member: Identifiable> {
    fileprivate var storage: [String: Member]

    public init(values: [Member] = []) {
        var storage = [String: Member](minimumCapacity: values.count)
        for value in values {
            storage[value.identifier] = value
        }
        self.storage = storage
    }

    public mutating func insert(member: Member) {
        storage[member.identifier] = member
    }

    public mutating func remove(member: Member) {
        removeFor(identifier: member.identifier)
    }

    public mutating func removeFor(identifier: String) {
        storage[identifier] = nil
    }

    public func memberMatching(member: Member) -> Member? {
        return memberFor(identifier: member.identifier)
    }

    public func memberFor(identifier: String) -> Member? {
        return storage[identifier]
    }

    public func contains(member: Member) -> Bool {
        return memberMatching(member: member) != nil
    }

    subscript(identifier: String) -> Member? {
        get { return memberFor(identifier: identifier) }
        // set subscript doesn't make sense, you use `add` instead
    }
}

extension IdentitySet: ExpressibleByArrayLiteral {
    public typealias Element = Member

    public init(arrayLiteral elements: IdentitySet.Element...) {
        self.init(values: elements)
    }
}

extension IdentitySet: Sequence {
    public typealias Generator = IdentitySetGenerator<Member>

    public func makeIterator() -> Generator {
        return IdentitySetGenerator(dictionaryIterator: storage.makeIterator())
    }
}

public struct IdentitySetGenerator<GeneratedType: Identifiable>: IteratorProtocol {
    public typealias Element = GeneratedType

    private var dictionaryIterator: DictionaryIterator<String, GeneratedType>

    init(dictionaryIterator: DictionaryIterator<String, GeneratedType>) {
        self.dictionaryIterator = dictionaryIterator
    }

    public mutating func next() -> Element? {
        return dictionaryIterator.next()?.1
    }
}
