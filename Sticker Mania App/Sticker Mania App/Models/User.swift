struct User: Decodable, Identifiable {
    let id: String
    let email: String
    let name: String
    let role: UserRole
    let brands: [Brand]?
}
