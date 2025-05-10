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
