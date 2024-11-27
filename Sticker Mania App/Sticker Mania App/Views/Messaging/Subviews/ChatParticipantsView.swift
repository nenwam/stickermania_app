//
//  ChatParticipantsView.swift
//  Sticker Mania App
//
//  Created by Connor on 11/1/24.
//

import SwiftUI

struct ChatParticipantsView: View {
    let participants: [User]
    let chatType: ChatType
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text(chatType == .team ? "Team Chat" : "Customer Chat")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)
                
                List(participants) { participant in
                    Text(participant.name)
                }
            }
            .navigationTitle("Chat Participants")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
