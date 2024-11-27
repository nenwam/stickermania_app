import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @State private var selectedTab = 0
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            OrderCreationView()
                .tabItem {
                    Label("New Order", systemImage: "plus.circle")
                }
                .tag(0)
            
            NavigationView {
                ChatListView()
                    .navigationTitle("Messages")
            }
            .tabItem {
                Label("Messages", systemImage: "message")
            }
            .tag(1)
            
            NavigationView {
                OrderCustomerLookupView()  // Replace the placeholder with the new view
                    .navigationTitle("Orders")
            }
            .tabItem {
                Label("Orders", systemImage: "doc.text.magnifyingglass")
            }
            .tag(2)
            
            Button(action: {
                AuthenticationService.shared.signOut { _ in }
            }) {
                VStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("Sign Out")
                    if let email = Auth.auth().currentUser?.email {
                        Text(email.components(separatedBy: "@").first ?? "")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .tabItem {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .tag(3)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}