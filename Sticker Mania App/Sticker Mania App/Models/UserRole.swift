enum UserRole: String, Decodable, Identifiable {
    case customer = "customer"
    case accountManager = "accountManager"
    case employee = "employee"
    case admin = "admin"

    var id: String { self.rawValue }
}