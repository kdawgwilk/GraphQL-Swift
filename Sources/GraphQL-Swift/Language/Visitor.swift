
enum VisitAction {
    case `continue`
    case stop
    /// Skip doesn't make sense when returned from a "leave" closure and causes a fatal error.
    case skipHasSubtree
    case replaceValue(Node)
    case removeValue
}

enum NodeType: String {
    case any
    case document
    case operationDefinition
    case fragmentDefinition
    case fragmentSpread
    case field
    case directive
    case argument
    case variableDefinition
    case selectionSet
    case inlineFragment
    case intValue
    case floatValue
    case stringValue
    case boolValue
    case enumValue
    case listValue
    case inputObjectValue
    case inputObjectField
    case variable
    case namedType
    case nonNullType
    case listType


    var identifier: String { return rawValue }
}

enum VisitError: Error {
    case skipHasSubtree
    case stop
}

struct Visitor: Identifiable {
    let nodeType: NodeType
    let enter: ((Node) throws -> VisitAction)?
    let leave: ((Node) throws -> VisitAction)?

    init(nodeType: NodeType, enter: ((Node) throws -> VisitAction)? = nil, leave: ((Node) throws -> VisitAction)? = nil) {
        self.nodeType = nodeType
        self.enter = enter
        self.leave = leave
    }

    var identifier: String {
        return nodeType.identifier
    }
}

extension Node {
    func visit(visitor: Visitor) throws -> Node? {

        guard var afterEntering = try enter(visitor: visitor) else { return nil }

        if var tree = afterEntering as? HasSubtree {
            try tree.visitChildren(visitor: visitor)
            afterEntering = tree
        }

        guard let afterLeaving = try afterEntering.leave(visitor: visitor) else { return nil }

        return afterLeaving
    }

    private func enter(visitor: Visitor) throws -> Node? {
        guard let enter = visitor.enter else { return self }

        switch try enter(self) {
        case .continue: return self
        case .stop: throw VisitError.stop
        case .skipHasSubtree: throw VisitError.skipHasSubtree
        case .replaceValue(let newValue): return newValue
        case .removeValue: return nil
        }
    }

    private func leave(visitor: Visitor) throws -> Node? {
        guard let leave = visitor.leave else { return self }

        switch try leave(self) {
        case .continue: return self
        case .stop: throw VisitError.stop
        case .skipHasSubtree: fatalError("Developer error: there is no point in skipping a subtree after it has been visited")
        case .replaceValue(let newValue): return newValue
        case .removeValue: return nil
        }
    }
}

extension HasSubtree {

    fileprivate mutating func visitChildren(visitor: Visitor) throws {
        var currentIndex = 0
        while currentIndex < children.count {
            let child = children[currentIndex]
            let childModifiedByVisit = try child.visit(visitor: visitor)

            if let childModifiedByVisit = childModifiedByVisit {
                replaceChildAtIndex(index: currentIndex, newValue: childModifiedByVisit)
                currentIndex += 1
            } else {
                removeChildAtIndex(index: currentIndex)
                // Do not increase current index, everything has shifted down by one because the child was removed.
                // Keeping the same index will in fact visit the next child (or break the loop if it was the last child).
            }
        }
    }
}
