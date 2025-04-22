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
    @State private var activeNavigation: String? = nil
    @Binding var selectedChatId: String?
    
    // States for delete confirmation
    @State private var showDeleteConfirmation = false
    @State private var chatToDelete: String? = nil
    
    var filteredChats: [Chat] {
        // Get current user's email
        let currentUserEmail = Auth.auth().currentUser?.email ?? ""
        
        let filtered = viewModel.chats.filter { chat in
            if authViewModel.userRole == .admin || authViewModel.userRole == .accountManager || authViewModel.userRole == .employee {
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
    
    init(selectedChatId: Binding<String?> = .constant(nil)) {
        self._selectedChatId = selectedChatId
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
                
                if authViewModel.userRole == .admin || authViewModel.userRole == .accountManager || authViewModel.userRole == .employee {
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
                
                if selectedChatType == .team {
                    List(filteredChats) { chat in
                        NavigationLink(
                            destination: ChatDetailView(chatId: chat.id),
                            tag: chat.id,
                            selection: $activeNavigation
                        ) {
                            MessageCellView(chat: chat, viewModel: viewModel)
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
                    
                    // Add direct navigation link outside the list
                    // This will handle navigation even if the chat isn't in the list yet
                    if let targetChatId = selectedChatId, !filteredChats.contains(where: { $0.id == targetChatId }) {
                        NavigationLink(
                            destination: ChatDetailView(chatId: targetChatId),
                            tag: targetChatId,
                            selection: $activeNavigation
                        ) {
                            EmptyView() // Hidden link
                        }
                    }
                } else if selectedChatType == .customer {
                    CustomerChatTopicsView()
                    
                    // Add direct navigation link for customer chat view too
                    if let targetChatId = selectedChatId {
                        NavigationLink(
                            destination: ChatDetailView(chatId: targetChatId),
                            tag: targetChatId,
                            selection: $activeNavigation
                        ) {
                            EmptyView() // Hidden link
                        }
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
                    if authViewModel.userRole == .admin || authViewModel.userRole == .accountManager {
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
            .onChange(of: selectedChatId) { newChatId in
                if let chatId = newChatId {
                    print("ChatListView: selectedChatId changed to \(chatId)")
                    
                    // First check if this chat is already in our list
                    let chatExists = filteredChats.contains(where: { $0.id == chatId })
                    
                    if !chatExists {
                        // If chat isn't in the list, try to fetch it directly
                        print("ChatListView: Chat \(chatId) not in filtered list, fetching directly")
                        Task {
                            do {
                                // Check if chat exists in Firestore and user has access
                                try await viewModel.fetchSingleChat(chatId: chatId)
                                
                                // Set the active navigation on the main thread
                                DispatchQueue.main.async {
                                    print("ChatListView: Setting activeNavigation to \(chatId) after fetching")
                                    self.activeNavigation = chatId
                                    
                                    // Double-check navigation after a short delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        if self.activeNavigation != chatId {
                                            print("ChatListView: Navigation failed, trying again")
                                            self.activeNavigation = chatId
                                        }
                                    }
                                }
                            } catch {
                                print("ChatListView: Error fetching chat \(chatId): \(error.localizedDescription)")
                            }
                        }
                    } else {
                        // Chat exists in list, navigate directly
                        print("ChatListView: Chat \(chatId) found in list, navigating")
                        self.activeNavigation = chatId
                        
                        // Double-check navigation after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if self.activeNavigation != chatId {
                                print("ChatListView: Navigation failed, trying again")
                                self.activeNavigation = chatId
                            }
                        }
                    }
                    
                    // Reset selectedChatId after a delay
                    // DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    //     selectedChatId = nil
                    //     print("ChatListView: reset selectedChatId to nil")
                    // }
                }
            }
            .onAppear {
                viewModel.fetchChats()
                Task {
                    let (imageUrl, name) = await userViewModel.fetchProfileData()
                    profileImageUrl = imageUrl
                    profileName = name
                }
                
                // Set up listener for reset notification from ChatDetailView
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("ResetChatNavigation"),
                    object: nil,
                    queue: .main
                ) { _ in
                    print("ChatListView: Received ResetChatNavigation notification")
                    activeNavigation = nil
                    selectedChatId = nil
                }
            }
            .onDisappear {
                // Remove the observer
                NotificationCenter.default.removeObserver(
                    self,
                    name: Notification.Name("ResetChatNavigation"),
                    object: nil
                )
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