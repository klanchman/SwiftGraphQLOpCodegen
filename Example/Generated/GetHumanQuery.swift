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
