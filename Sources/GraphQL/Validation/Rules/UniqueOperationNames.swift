final class UniqueOperationNames: Rule {
    let context: ValidationContext
    required init(context: ValidationContext) {
        self.context = context
    }

    var knownOperationNames: Set<ValidName> = []

    func visitors() -> IdentitySet<Visitor> {
        return [Visitor(
            nodeType: .operationDefinition,
            enter: { operation in
                let operation = operation as! OperationDefinition
                guard let name = operation.name else { return .continue }

                guard !self.knownOperationNames.contains(name) else {
                    throw DocumentValidationError.duplicateOperationNames(name: name.string)
                }

                self.knownOperationNames.insert(name)

                return .continue
            })]
    }
}

