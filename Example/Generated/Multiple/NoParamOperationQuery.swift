extension APIOperation {
    struct NoParamOperation: GraphQLOperation {
        let operationName = "NoParamOperation"
        let query = "query NoParamOperation(){search{__typename}}"
        let variables: [String: String]? = nil
    }
}
