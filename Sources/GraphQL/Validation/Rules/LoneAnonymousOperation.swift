final class LoneAnonymousOperation: Rule {
    let context: ValidationContext
    required init(context: ValidationContext) {
        self.context = context
    }

    func visitors() -> IdentitySet<Visitor> {
        return []
    }
}