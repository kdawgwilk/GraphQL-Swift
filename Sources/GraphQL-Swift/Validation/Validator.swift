struct GraphQLError {
    let message: String
    let locations: [(line: Int, column: Int)]?
    let path: [String]?
    let nodes: [Node]?
    let source: Source?
    let positions: [Int]?
    let originalError: Error?
}

struct ValidationContext {
    let schema: GraphQLSchema
    let ast: Document
    let typeInfo: TypeInfo
    var errors: [GraphQLError]
    var fragments: [String: FragmentDefinition]?
    let fragmentSpreads: [SelectionSet: [FragmentSpread]]
    let recursivelyReferencedFragments: [OperationDefinition: [FragmentDefinition]]
    let variableUsages: [HasSelectionSet: [VariableUsage]]
    let recursiveVariableUsages: [OperationDefinition: [VariableUsage]]

    mutating func report(error: GraphQLError) {
        errors.append(error)
    }

    func getErrors() -> [GraphQLError] {
        return errors
    }

    func getSchema() -> GraphQLSchema {
        return schema
    }

    func getDocument() -> Document {
        return ast
    }

    mutating func getFragment(name: String) -> FragmentDefinition? {
        if let fragments = self.fragments {
            return fragments[name]
        } else {
            self.fragments = getDocument().definitions.reduce { (frags, statement) in
                if (statement.kind === Kind.FRAGMENT_DEFINITION) {
                    frags[statement.name.value] = statement
                }
                return frags
            }
        }
    }

    func getFragmentSpreads(node: SelectionSet) -> [FragmentSpread] {
        if let spreads = fragmentSpreads.get(node) {
            return spreads
        } else {
            spreads = []
            let setsToVisit: Array<SelectionSet> = [ node ]
            while (setsToVisit.length !== 0) {
                let set = setsToVisit.pop()
                for (let i = 0 i < set.selections.length i++) {
                    let selection = set.selections[i]
                    if (selection.kind === Kind.FRAGMENT_SPREAD) {
                        spreads.push(selection)
                    } else if (selection.selectionSet) {
                        setsToVisit.push(selection.selectionSet)
                    }
                }
            }
            self.fragmentSpreads.set(node, spreads)
        }
    }

    func getRecursivelyReferencedFragments(operation: OperationDefinition) -> [FragmentDefinition] {
        let fragments = self.recursivelyReferencedFragments.get(operation)
        if (!fragments) {
            fragments = []
            var collectedNames = [:]
            let nodesToVisit: Array<SelectionSet> = [ operation.selectionSet ]
            while (nodesToVisit.length !== 0) {
                let node = nodesToVisit.pop()
                let spreads = self.getFragmentSpreads(node)
                for (let i = 0 i < spreads.length i++) {
                    let fragName = spreads[i].name.value
                    if (collectedNames[fragName] !== true) {
                        collectedNames[fragName] = true
                        let fragment = self.getFragment(fragName)
                        if (fragment) {
                            fragments.push(fragment)
                            nodesToVisit.push(fragment.selectionSet)
                        }
                    }
                }
            }
            self.recursivelyReferencedFragments.set(operation, fragments)
        }
        return fragments
    }

    func getVariableUsages(node: HasSelectionSet) -> [VariableUsage] {
        let usages = self.variableUsages.get(node)
        if (!usages) {
            let newUsages = []
            let typeInfo = new TypeInfo(self.schema)
            visit(node, visitWithTypeInfo(typeInfo, {
                VariableDefinition: () => false,
                Variable(variable) {
                    newUsages.push({ node: variable, type: typeInfo.getInputType() })
                }
            }))
            usages = newUsages
            self.variableUsages.set(node, usages)
        }
        return usages
    }

    func getRecursiveVariableUsages(operation: OperationDefinition) -> [VariableUsage] {
        let usages = self.recursiveVariableUsages.get(operation)
        if (!usages) {
            usages = self.getVariableUsages(operation)
            let fragments = self.getRecursivelyReferencedFragments(operation)
            for (let i = 0 i < fragments.length i++) {
                Array.prototype.push.apply(
                    usages,
                    self.getVariableUsages(fragments[i])
                )
            }
            self.recursiveVariableUsages.set(operation, usages)
        }
        return usages
    }

    func getType() -> GraphQLOutputType? {
        return self.typeInfo.getType()
    }

    func getParentType() -> GraphQLCompositeType? {
        return self.typeInfo.getParentType()
    }

    func getInputType() -> GraphQLInputType? {
        return self.typeInfo.getInputType()
    }

    func getFieldDef() -> GraphQLFieldDefinition? {
        return self.typeInfo.getFieldDef()
    }

    func getDirective() -> GraphQLDirective? {
        return self.typeInfo.getDirective()
    }

    func getArgument() -> GraphQLArgument? {
        return self.typeInfo.getArgument()
    }
}

// TODO: Location reporting
public enum DocumentValidationError: Error {
    case duplicateOperationNames(name: String)
    case duplicateArgumentNames(name: String)
    case variableIsNonInputType
}

extension Document {
    func validateFor(schema: GraphQLSchema, ruleInitializers: [(ValidationContext) -> Rule] = allRules) throws {
        let typeInfo = TypeInfo(schema: schema)
        let context = ValidationContext(schema: schema, document: self, typeInfo: typeInfo)
        let rules = ruleInitializers.map { $0(context) }
        var errors: [Error] = []

        for rule in rules {
            do {
                try visitUsing(rule: rule, typeInfo: typeInfo)
            } catch let error {
                errors.append(error)
            }
        }

        switch errors.count {
        case 1: throw errors.first!
        case _ where errors.count > 1: throw GraphQLComposedError.MultipleErrors(errors)
        default: break
        }

    }

    func visitUsing(rule: Rule, typeInfo: TypeInfo) throws {

        let _ = try visit(visitor: Visitor(nodeType: .any,

            enter: { node in
                print("Entering \(node.type.rawValue)")
                typeInfo.enter(node: node)

                guard let visitor = rule.findVisitorFor(node: node),
                    let enter = visitor.enter else { return .continue }

                let action = try enter(node)

                if case .skipHasSubtree = action {
                    typeInfo.leave(node: node)
                }

                return action },

            leave: { node in
                print("Leaving \(node.type.rawValue)")

                guard let visitor = rule.findVisitorFor(node: node),
                    let leave = visitor.leave else { return .continue }

                let action = try leave(node)
                
                typeInfo.leave(node: node)
                
                return action }))
    }
}

extension Rule {

    fileprivate func findVisitorFor(node: Node) -> Visitor? {
        let cachedVisitors = visitors()
        let specificVisitor = cachedVisitors.memberFor(identifier: node.type.identifier)
        let anyVisitor = cachedVisitors.memberFor(identifier: NodeType.any.identifier)
        return specificVisitor ?? anyVisitor
    }
}
