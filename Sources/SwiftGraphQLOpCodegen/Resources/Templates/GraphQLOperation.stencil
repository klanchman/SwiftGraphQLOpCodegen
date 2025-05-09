protocol GraphQLOperation<Variables>: Encodable {
    associatedtype Variables: Encodable

    var operationName: String { get }
    var query: String { get }
    var variables: Variables { get }
}

enum APIOperation {}
