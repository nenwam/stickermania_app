import SwiftUI

struct MessageCell: View {
    let message: ChatMessage
    let hasUnreadMessages: Bool
    let participants: [String]
    let title: String? // Add title parameter
    
    init(message: ChatMessage, hasUnreadMessages: Bool, participants: [String], title: String?) {
        self.message = message
        self.hasUnreadMessages = hasUnreadMessages
        self.participants = participants
        self.title = title
        print("Title: \(title ?? "No title")")
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title ?? participants.joined(separator: ", ")) // Show title if available, otherwise show participants
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                
                Text(participants.joined(separator: ", "))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Text(message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if hasUnreadMessages {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }
}

struct MessageCell_Previews: PreviewProvider {
    static var previews: some View {
        MessageCell(
            message: ChatMessage(
                id: "1",
                senderId: "user1", 
                text: "Hello, this is a sample message",
                mediaUrl: nil,
                mediaType: nil,
                timestamp: Date()
            ),
            hasUnreadMessages: true,
            participants: ["user1", "user2"],
            title: "Team Chat"
        )
    }
}
