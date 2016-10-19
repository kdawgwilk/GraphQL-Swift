enum GraphQLFormattedError: Error {
    case Unknown
}

struct GraphQLResult {
    let data: Any?
    let errors: [GraphQLFormattedError]?
}

enum GraphQLComposedError: Error {
    case MultipleErrors([Error])
}


func graphql(schema: GraphQLSchema, requestString: String = "", rootValue: Any?, variableValues: [String: Any]?, operationName: String?, completion: ((GraphQLResult) -> ())?) throws {
    do {
        let source = Source(body: requestString, name: "GraphQL request")
        let request = try Parser.parse(source: source)
        try request.validateFor(schema: schema)
        execute(schema: schema, rootValue: rootValue, request: request, operationName: operationName, variableValues: variableValues)
    } catch let error {
        // TODO: Error processing
        throw error
    }

}


