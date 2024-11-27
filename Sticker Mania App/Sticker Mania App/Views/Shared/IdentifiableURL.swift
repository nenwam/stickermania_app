import Foundation

struct IdentifiableURL: Identifiable {
    let id = UUID() // Unique identifier for each instance
    let url: URL
}