
struct CreateReview: Encodable {
    let operationName = "CreateReview"
    let query = "mutation CreateReview($episode:Episode!,$review:ReviewInput!){createReview(episode:$episode,review:$review){...ReviewBasicInfo}}fragment ReviewBasicInfo on Review{stars episode}"
    let variables: Variables

    struct Variables: Encodable {
        let episode: Episode
        let review: ReviewInput
    }
}

struct GetHuman: Encodable {
    let operationName = "GetHuman"
    let query = "query GetHuman($id:ID!){human(id:$id){...CharacterBasicInfo mass}}fragment CharacterBasicInfo on Character{id name}"
    let variables: Variables

    struct Variables: Encodable {
        let id: ID
    }
}

struct GetReviews: Encodable {
    let operationName = "GetReviews"
    let query = "query GetReviews($episode:Episode!){reviews(episode:$episode){...ReviewBasicInfo}}fragment ReviewBasicInfo on Review{stars episode}"
    let variables: Variables

    struct Variables: Encodable {
        let episode: Episode
    }
}
