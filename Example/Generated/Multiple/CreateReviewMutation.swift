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
