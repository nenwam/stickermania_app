import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ChatListView: View {
    @StateObject private var userViewModel = UserProfileViewModel()
    @StateObject private var viewModel = ChatListViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showingChatCreation = false
    @State private var showingUserCreation = false
    @State private var showingMultiChatCreation = false
    @State private var selectedChatType: ChatType = .team
    @State private var profileImageUrl: String?
    @State private var profileName: String?
    var filteredChats: [Chat] {
        // Get current user's email
        let currentUserEmail = Auth.auth().currentUser?.email ?? ""
        
        let filtered = viewModel.chats.filter { chat in
            if authViewModel.userRole == .admin || authViewModel.userRole == .accountManager {
                return chat.type == selectedChatType && chat.participants.contains(currentUserEmail)
            } else {
                return chat.participants.contains(currentUserEmail)
            }
        }
        print("Current user email: \(currentUserEmail)")
        print("Filtered Chats for \(selectedChatType.rawValue): \(filtered.map { $0.id })")
        print("All participants: \(filtered.map { $0.participants })")
        return filtered
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                
                // Profile Picture Section
                if let profileImageUrl = profileImageUrl,
                    let url = URL(string: profileImageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 120)
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 120)
                }
                
                if let name = profileName {
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                    .frame(height: 12)
                
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
                    .padding([.horizontal, .bottom])
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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Messages")
                        .font(.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authViewModel.userRole == .admin || authViewModel.userRole == .accountManager || authViewModel.userRole == .employee {
                        HStack {
                            Button(action: {
                                showingMultiChatCreation = true
                            }) {
                                Image(systemName: "person.2.fill")
                            }
                            
                            Button(action: {
                                showingChatCreation = true
                            }) {
                                Image(systemName: "square.and.pencil")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingChatCreation) {
                ChatCreationView()
                    .onDisappear {
                        viewModel.fetchChats() // Refresh chats when creation sheet is dismissed
                    }
            }
            .sheet(isPresented: $showingMultiChatCreation) {
                ChatMultiCreationView()
                    .onDisappear {
                        viewModel.fetchChats() // Refresh chats when multi chat creation is dismissed
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
                Task {
                    let (imageUrl, name) = await userViewModel.fetchProfileData()
                    profileImageUrl = imageUrl
                    profileName = name
                }
            }
            
            BackgroundLogo(opacity: 0.2)
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
                    hasUnreadMessages: chat.hasUnreadMessages(for: Auth.auth().currentUser?.email ?? ""),
                    participants: participantNames,
                    title: chat.title
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