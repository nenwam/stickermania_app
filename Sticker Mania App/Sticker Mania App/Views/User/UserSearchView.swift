import SwiftUI

struct UserSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @StateObject private var viewModel = ChatParticipantSelectViewModel()
    
    var body: some View {
        VStack {
            // Search input
            TextField("Search users by name or ID...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .onChange(of: searchText) { newValue in
                    Task {
                        await viewModel.searchUsers(matching: newValue)
                    }
                }
            
            // Search results
            if !searchText.isEmpty {
                List(viewModel.filteredUsers, id: \.id) { user in
                    NavigationLink(destination: UserDetailView(userId: user.id)) {
                        VStack(alignment: .leading) {
                            Text(user.name)
                                .font(.headline)
                            Text("ID: \(user.id)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            } else {
                Text("Enter a name or ID to search")
                    .foregroundColor(.gray)
                    .padding(.top)
                Spacer()
            }
        }
        .navigationTitle("User Search")
    }
}

#Preview {
    NavigationView {
        UserSearchView()
    }
}
