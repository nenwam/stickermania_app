import SwiftUI

struct ChatParticipantSelectView: View {
    @Binding var selectedParticipants: [String]
    @State private var searchText = ""
    @State private var filteredUsers: [User] = []
    @StateObject private var viewModel = ChatParticipantSelectViewModel()
    
    var body: some View {
        VStack {
            // Search input
            TextField("Search users...", text: $searchText)
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
                    HStack {
                        Text(user.name) // Ensure this is a String
                        Spacer()
                        if selectedParticipants.contains(user.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let index = selectedParticipants.firstIndex(of: user.id) {
                            selectedParticipants.remove(at: index)
                        } else {
                            selectedParticipants.append(user.id)
                        }
                    }
                }
            }
            
            // Selected participants
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach($selectedParticipants, id: \.self) { $participantId in
                        if let user = viewModel.getUser(by: participantId) {
                            Chip(text: user.name) {
                                if let index = selectedParticipants.firstIndex(of: participantId) {
                                    selectedParticipants.remove(at: index)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// Helper view for selected participants
struct Chip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Text(text)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.2))
        .clipShape(Capsule())
    }
}


#Preview {
    ChatParticipantSelectView(selectedParticipants: .constant([]))
}
