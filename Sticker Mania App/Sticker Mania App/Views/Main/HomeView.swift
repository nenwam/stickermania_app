import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @State private var selectedTab = 0
    @StateObject private var authViewModel = AuthViewModel()
    
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
                    ChatListView()
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
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}