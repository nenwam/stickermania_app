//
//  ChatRowView.swift
//  Sticker Mania App
//
//  Created by Connor on 4/18/25.
//

import SwiftUI

struct ChatRowView: View {
    // Accept a User object
    let user: User
    let hasUnreadMessages: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) { // Use VStack with spacing like MessageCell
                Text(user.name) // Primary text: User's name
                    .foregroundColor(.primary)
                    .fontWeight(.medium) // Style like MessageCell title
                
                Text(user.email) // Secondary text: User's email
                    .foregroundColor(.secondary)
                    .font(.subheadline) // Style like MessageCell secondary text
            }
            
            Spacer() // Keep spacer
            
            // Add the blue dot if there are unread messages
            if hasUnreadMessages {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8) // Add padding like MessageCell
        .padding(.horizontal)
    }
}

#Preview {
    // Example preview usage
    let previewUser = User(id: "previewUser", email: "customer@example.com", name: "Sample Customer", role: .customer)
    return VStack {
        ChatRowView(user: previewUser, hasUnreadMessages: true)
            .padding()
        ChatRowView(user: previewUser, hasUnreadMessages: false)
            .padding()
    }
}
