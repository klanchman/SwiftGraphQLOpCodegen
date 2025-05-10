protocol GraphQLOperation<Variables>: Encodable {
    associatedtype Variables: Encodable

    var operationName: String { get }
    var query: String { get }
    var variables: Variables { get }
}

enum APIOperation {}

extension APIOperation {
    struct CreateReview: GraphQLOperation {
        let operationName = "CreateReview"
        let query = "mutation CreateReview($episode:Episode!,$review:ReviewInput!){createReview(episode:$episode,review:$review){...ReviewBasicInfo}}fragment ReviewBasicInfo on Review{stars episode}"
        let variables: Variables

        struct Variables: Encodable {
            let episode: Episode
            let review: ReviewInput
        }
    }
}

extension APIOperation {
    struct GetHuman: GraphQLOperation {
        let operationName = "GetHuman"
        let query = "query GetHuman($id:ID!){human(id:$id){...CharacterBasicInfo mass}}fragment CharacterBasicInfo on Character{id name}"
        let variables: Variables

        struct Variables: Encodable {
            let id: ID
        }
    }
}

extension APIOperation {
    struct GetReviews: GraphQLOperation {
        let operationName = "GetReviews"
        let query = "query GetReviews($episode:Episode!){reviews(episode:$episode){...ReviewBasicInfo}}fragment ReviewBasicInfo on Review{stars episode}"
        let variables: Variables

        struct Variables: Encodable {
            let episode: Episode
        }
    }
}

extension APIOperation {
    struct NoParamOperation: GraphQLOperation {
        let operationName = "NoParamOperation"
        let query = "query NoParamOperation(){search{__typename}}"
        let variables: Never
    }
}
