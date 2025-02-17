import SwiftUI

struct UserSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @StateObject private var viewModel = ChatParticipantSelectViewModel()
    
    var body: some View {
        VStack {
            // Search input
            TextField("Search users by name or email...", text: $searchText)
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
                        HStack {
                            if let profileImageUrl = user.profilePictureUrl,
                               let url = URL(string: profileImageUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 40, height: 40)
                                }
                            } else {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 40, height: 40)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text("ID: \(user.id)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
            } else {
                Text("Enter a name or email to search")
                    .foregroundColor(.gray)
                    .padding(.top)
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationView {
        UserSearchView()
    }
}
