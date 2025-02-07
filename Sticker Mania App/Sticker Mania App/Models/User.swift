struct User: Decodable, Identifiable {
    let id: String
    var email: String
    var name: String
    var role: UserRole
    var brands: [Brand]?
    var profilePictureUrl: String?
    var userRelations: [User]?
}
