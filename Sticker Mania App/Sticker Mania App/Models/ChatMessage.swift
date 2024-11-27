import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let senderId: String
    let text: String?
    let mediaUrl: String?
    let mediaType: MediaType?
    let timestamp: Date
}

enum MediaType: String, Codable {
    case text
    case image
    case video
    case pdf
}
