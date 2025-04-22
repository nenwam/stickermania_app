import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @State private var selectedTab = 0
    @StateObject private var authViewModel = AuthViewModel()
    @State private var selectedChatId: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            Image("sm_dice_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 40)
                .padding(.vertical, 2)
            
            TabView(selection: $selectedTab) {
                OrderCreationView()
                    .tabItem {
                        Label("New Order", systemImage: "plus.circle")
                    }
                    .tag(0)
                
                NavigationView {
                    ChatListView(selectedChatId: $selectedChatId)
                }
                .tabItem {
                    Label("Messages", systemImage: "message")
                }
                .tag(1)
                
                NavigationView {
                    OrderCustomerLookupView()  // Replace the placeholder with the new view
                }
                .tabItem {
                    Label("Search", systemImage: "doc.text.magnifyingglass")
                }
                .tag(2)
                
                NavigationView {
                    UserProfileView()
                }
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(3)
            }
        }
        .onAppear {
            // Set up notification observer for chat messages
            NotificationCenter.default.addObserver(
                forName: Notification.Name("OpenChat"),
                object: nil,
                queue: .main
            ) { notification in
                if let chatId = notification.userInfo?["chatId"] as? String {
                    print("HomeView: Received notification to open chat: \(chatId)")
                    
                    // First set the selectedChatId
                    self.selectedChatId = chatId
                    
                    // Then switch to messages tab with a slight delay
                    // This ensures the chat list view is ready to handle the navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.selectedTab = 1
                        print("HomeView: Switched to messages tab (tab 1) for chat: \(chatId)")
                    }
                }
            }
        }
        .onDisappear {
            // Remove observer when view disappears
            NotificationCenter.default.removeObserver(self, name: Notification.Name("OpenChat"), object: nil)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}