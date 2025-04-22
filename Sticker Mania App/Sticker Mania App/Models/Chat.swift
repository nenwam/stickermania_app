import Foundation
import FirebaseFirestore

struct Chat: Identifiable, Decodable {
    let id: String
    let participants: [String]
    let lastMessage: ChatMessage
    let type: ChatType
    let unreadStatus: [String: Bool] // Updated to track unread status per participant
    let title: String? // Optional chat title

    // Updated initializer
    init(id: String, participants: [String], lastMessage: ChatMessage, type: ChatType, unreadStatus: [String: Bool] = [:], title: String? = nil) {
        self.id = id
        self.participants = participants
        self.lastMessage = lastMessage
        self.type = type
        self.unreadStatus = unreadStatus
        self.title = title
    }

    init?(document: DocumentSnapshot) {
        let data = document.data()
        guard let participants = data?["participants"] as? [String],
              let lastMessageData = data?["lastMessage"] as? [String: Any],
              let messageId = lastMessageData["id"] as? String,
              let senderId = lastMessageData["senderId"] as? String,
              let text = lastMessageData["text"] as? String,
              let timestamp = (lastMessageData["timestamp"] as? Timestamp)?.dateValue(),
              let typeString = data?["type"] as? String,
              let type = ChatType(rawValue: typeString),
              let unreadStatus = data?["unreadStatus"] as? [String: Bool] else {
            return nil
        }

        let lastMessage = ChatMessage(
            id: messageId,
            senderId: senderId,
            text: text,
            mediaUrl: nil,
            thumbnailUrl: nil,
            mediaType: nil,
            timestamp: timestamp
        )

        self.init(
            id: document.documentID,
            participants: participants,
            lastMessage: lastMessage,
            type: type,
            unreadStatus: unreadStatus,
            title: data?["title"] as? String
        )
    }

    // Computed property to check if the current user has unread messages
    func hasUnreadMessages(for userId: String) -> Bool {
        return unreadStatus[userId] ?? false
    }
}
