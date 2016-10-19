final class UniqueArgumentNames: Rule {
    let context: ValidationContext
    required init(context: ValidationContext) {
        self.context = context
    }

    var knownArgumentNames: Set<ValidName> = []

    func visitors() -> IdentitySet<Visitor> {
        return [
            Visitor(nodeType: .field,
                enter: { field in
                    self.knownArgumentNames = []
                    return .continue
            }),
            Visitor(nodeType: .directive,
                enter: { directive in
                    self.knownArgumentNames = []
                    return .continue
                }),
            Visitor(nodeType: .argument,
                enter: { argument in
                    let argument = argument as! Argument
                    guard !self.knownArgumentNames.contains(argument.name) else {
                        throw DocumentValidationError.duplicateArgumentNames(name: argument.name.string)
                    }

                    self.knownArgumentNames.insert(argument.name)

                    return .continue
                }),
        ]
    }
}


