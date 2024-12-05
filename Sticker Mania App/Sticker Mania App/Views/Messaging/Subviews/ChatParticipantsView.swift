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
                    HStack {
                        if let profileImageUrl = participant.profilePictureUrl,
                           let url = URL(string: profileImageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 40, height: 40)
                            }
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                        }
                        
                        Text(participant.name)
                            .padding(.leading, 8)
                    }
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
