import SwiftUI
import FirebaseAuth
struct MessageBubble: View {
    let message: ChatMessage
    let participants: [User]
    
    private var senderName: String {
        print("Participants: \(participants.map { "\($0.email): \($0.name)" })")

        if message.senderId == Auth.auth().currentUser?.email ?? "" {
            return "You"
        } else {
            // Print debug info
            print("Message sender ID:", message.senderId)
            print("Participants:", participants.map { "\($0.email): \($0.name)" })
            
            // Trim whitespace and compare case-insensitively
            if let participant = participants.first(where: { participant in
                print("Comparing \(participant.email) with \(message.senderId)")
                let normalizedParticipantEmail = participant.email.trimmingCharacters(in: .whitespaces).lowercased()
                let normalizedSenderId = message.senderId.trimmingCharacters(in: .whitespaces).lowercased()
                return normalizedParticipantEmail == normalizedSenderId
            }) {
                return participant.name
            } else {
                // Additional debug info
                print("No matching participant found for sender ID:", message.senderId)
                print("Available participant emails:", participants.map { $0.email })
                return "Unknown User"
            }
        }
    }
    
    var body: some View {
        HStack {
            if message.senderId == Auth.auth().currentUser?.email ?? "" {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Group {
                        if Calendar.current.isDateInToday(message.timestamp) {
                            Text(message.timestamp, style: .time)
                        } else {
                            Text(message.timestamp, style: .date) + Text(" ") + Text(message.timestamp, style: .time)
                        }
                    }
                    .font(.system(size: 8))
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
                    Group {
                        if Calendar.current.isDateInToday(message.timestamp) {
                            Text(message.timestamp, style: .time)
                        } else {
                            Text(message.timestamp, style: .date) + Text(" ") + Text(message.timestamp, style: .time)
                        }
                    }
                    .font(.system(size: 8))
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