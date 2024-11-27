import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showingChatCreation = false
    @State private var showingUserCreation = false
    @State private var selectedChatType: ChatType = .team
    
    var filteredChats: [Chat] {
        // Get current user's email prefix as that's what we store in participants
        let currentUserId = Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? ""
        
        let filtered = viewModel.chats.filter { chat in
            if authViewModel.userRole == .admin || authViewModel.userRole == .accountManager {
                return chat.type == selectedChatType && chat.participants.contains(currentUserId)
            } else {
                return chat.participants.contains(currentUserId)
            }
        }
        print("Current user ID: \(currentUserId)")
        print("Filtered Chats for \(selectedChatType.rawValue): \(filtered.map { $0.id })")
        print("All participants: \(filtered.map { $0.participants })")
        return filtered
    }
    
    var body: some View {
        VStack {
            if authViewModel.userRole == .admin || authViewModel.userRole == .accountManager {
                HStack {
                    Picker("Chat Type", selection: $selectedChatType) {
                        Text("Team").tag(ChatType.team)
                        Text("Customer").tag(ChatType.customer)
                    }
                    .pickerStyle(.segmented)
                    
                    Button(action: {
                        viewModel.fetchChats()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .imageScale(.large)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .onChange(of: selectedChatType) { newValue in
                    print("Selected ChatType changed to: \(newValue.rawValue)")
                    viewModel.fetchChats() // Refresh chats when type changes
                }
            }
            
            List(filteredChats) { chat in
                NavigationLink(destination: ChatDetailView(chatId: chat.id)) {
                    MessageCellView(chat: chat, viewModel: viewModel)
                }
            }
        }
        .navigationTitle("Messages")
        .navigationBarItems(
            trailing: Group {
                if authViewModel.userRole == .admin || authViewModel.userRole == .accountManager || authViewModel.userRole == .employee {
                    Button(action: {
                        showingChatCreation = true
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        )
        .sheet(isPresented: $showingChatCreation) {
            ChatCreationView()
                .onDisappear {
                    viewModel.fetchChats() // Refresh chats when creation sheet is dismissed
                }
        }
        .sheet(isPresented: $showingUserCreation) {
            ChatUserCreationTest()
                .onDisappear {
                    viewModel.fetchChats() // Refresh chats when user creation is dismissed
                }
        }
        .onAppear {
            viewModel.fetchChats()
        }
    }
}

struct MessageCellView: View {
    let chat: Chat
    @ObservedObject var viewModel: ChatListViewModel
    
    @State private var participantNames: [String] = []
    
    var body: some View {
        VStack {
            if participantNames.isEmpty {
                // Placeholder view while names are being fetched
                Text("Loading names...")
                    .onAppear {
                        viewModel.getParticipantNames(for: chat.participants) { names in
                            participantNames = names
                        }
                    }
            } else {
                // Ensure the MessageCell initializer matches the expected parameters
                MessageCell(
                    message: chat.lastMessage,
                    hasUnreadMessages: chat.hasUnreadMessages(for: Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? ""),
                    participants: participantNames // Pass the participant names here
                )
            }
        }
    }
}

struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatListView()
        }
    }
}