import Foundation
import FirebaseFirestore

struct Message {
    let id: String
    let senderId: String
    let recipientId: String
    let content: String
    let timestamp: Date
}

let db = Firestore.firestore()

func saveMessage(message: Message) {
    let messageRef = db.collection("messages").document(message.id)
    messageRef.setData([
        "senderId": message.senderId,
        "receiverId": message.recipientId,
        "content": message.content,
        "timestamp": message.timestamp
    ]) { error in
        if let error = error {
            print("Error saving message: \(error)")
        } else {
            print("Message saved successfully")
        }
    }
}
