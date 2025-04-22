//
//  CustomerChatListView.swift
//  Sticker Mania App
//
//  Created by Connor on 4/18/25.
//

import SwiftUI
import Firebase
import FirebaseAuth


struct CustomerChatListView: View {
    // Accept a customerId and create the view model with it
    let customerId: String
    @StateObject private var viewModel: CustomerChatListViewModel
    
    // States for delete confirmation
    @State private var showDeleteConfirmation = false
    @State private var chatToDelete: String? = nil
    
    // Custom initializer to create the view model with the customerId
    init(customerId: String) {
        self.customerId = customerId
        // Use _StateObject syntax to initialize the StateObject property wrapper
        _viewModel = StateObject(wrappedValue: CustomerChatListViewModel(customerId: customerId))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, minHeight: 200) // Ensure consistent height
            } else if let error = viewModel.error {
                Text("Error loading chats: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 200) // Ensure consistent height
            } else if viewModel.chats.isEmpty {
                Text("No chats found with this customer.")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 200) // Ensure consistent height
            } else {
                List(viewModel.chats) { chat in
                    // Wrap CustomerChatCell in a NavigationLink
                    NavigationLink(destination: ChatDetailView(chatId: chat.id)) { 
                        CustomerChatCell(chat: chat, viewModel: viewModel)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if viewModel.canDeleteChats {
                            Button(role: .destructive) {
                                chatToDelete = chat.id
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle()) // Clean list style
                .refreshable {
                    viewModel.fetchChats() // Pull to refresh functionality
                }
                .alert("Delete Chat", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {
                        chatToDelete = nil
                    }
                    Button("Delete", role: .destructive) {
                        if let chatId = chatToDelete {
                            viewModel.deleteChat(chatId: chatId)
                            chatToDelete = nil
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete this chat? This action cannot be undone.")
                }
            }
        }
        .onAppear {
            // Fetch chats when view appears (though already done in init)
            viewModel.fetchChats()
        }
    }
}

// Custom cell view for displaying chats, based on MessageCellView
struct CustomerChatCell: View {
    let chat: Chat
    @ObservedObject var viewModel: CustomerChatListViewModel
    
    @State private var participantNames: [String] = []
    
    var body: some View {
        VStack {
            if participantNames.isEmpty {
                // Placeholder view while names are being fetched
                Text("Loading participants...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .onAppear {
                        viewModel.getParticipantNames(for: chat.participants) { names in
                            participantNames = names
                        }
                    }
            } else {
                // Using the same MessageCell component as in ChatListView
                MessageCell(
                    message: chat.lastMessage,
                    hasUnreadMessages: chat.hasUnreadMessages(for: Auth.auth().currentUser?.email ?? ""),
                    participants: participantNames,
                    title: chat.title
                )
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    // Create a mock customer ID for preview purposes
    CustomerChatListView(customerId: "customer@example.com")
}
