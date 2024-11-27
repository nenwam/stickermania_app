import SwiftUI
import FirebaseAuth
struct MessageBubble: View {
    let message: ChatMessage
    let participants: [User]
    
    private var senderName: String {
        if message.senderId == Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? "" {
            return "You"
        } else {
            return participants.first(where: { $0.id == message.senderId })?.name ?? message.senderId
        }
    }
    
    var body: some View {
        HStack {
            if message.senderId == Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? "" {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(message.text ?? "")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(message.text ?? "")
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Spacer()
            }
        }
    }
}