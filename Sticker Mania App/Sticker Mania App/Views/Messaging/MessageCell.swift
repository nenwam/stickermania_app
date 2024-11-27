import SwiftUI

struct MessageCell: View {
    let message: ChatMessage
    let hasUnreadMessages: Bool // This should be passed in as a parameter
    let participants: [String] // Add participants parameter
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text((message.text?.count ?? 0 > 50) ? String(message.text?.prefix(50) ?? "") + "..." : message.text ?? "")
                    .foregroundColor(.primary)
                
                Text(message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(participants.joined(separator: ", "))
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
            participants: ["user1", "user2"]
        )
    }
}
