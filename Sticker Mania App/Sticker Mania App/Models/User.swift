struct User: Decodable, Identifiable, Hashable {
    let id: String
    var email: String
    var name: String
    var role: UserRole
    var brands: [Brand]?
    var profilePictureUrl: String?
    var userRelationIds: [String]?
}
