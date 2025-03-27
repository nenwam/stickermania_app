//
//  UserAddRelation.swift
//  Sticker Mania App
//
//  Created by Connor on 12/19/24.
//

import SwiftUI

struct UserAddRelationView: View {
    let userId: String
    @StateObject private var viewModel = UserAddRelationViewModel()
    @State private var searchText = ""
    @State private var selectedUsers: [User] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            if let user = viewModel.user {
                // Search input
                TextField("Search users by name or email...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .onChange(of: searchText) { newValue in
                        Task {
                            if user.role == .customer {
                                await viewModel.searchUsers(matching: newValue, role: .accountManager)
                            } else {
                                await viewModel.searchUsers(matching: newValue, role: .customer)
                            }
                        }
                    }
                
                // Search results
                if !searchText.isEmpty {
                    List(viewModel.filteredUsers, id: \.id) { searchedUser in
                        HStack {
                            if let profileImageUrl = searchedUser.profilePictureUrl,
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
                                Text(searchedUser.name)
                                    .font(.headline)
                                Text(searchedUser.email)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.leading, 8)
                            
                            Spacer()
                            
                            if user.role == .customer {
                                // Single selection for customers
                                if selectedUsers.contains(where: { $0.id == searchedUser.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            } else {
                                // Multi selection for account managers
                                if selectedUsers.contains(where: { $0.id == searchedUser.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .onTapGesture {
                            if user.role == .customer {
                                // Single selection
                                selectedUsers = [searchedUser]
                            } else {
                                // Multi selection
                                if let index = selectedUsers.firstIndex(where: { $0.id == searchedUser.id }) {
                                    selectedUsers.remove(at: index)
                                } else {
                                    selectedUsers.append(searchedUser)
                                }
                            }
                        }
                    }
                } else {
                    Text("Enter a name or email to search")
                        .foregroundColor(.gray)
                        .padding(.top)
                    Spacer()
                }
                
                Button("Done") {
                    if user.role == .customer {
                        // Pass customer and selected account manager
                        if let accountManager = selectedUsers.first {
                            Task {
                                let success = await viewModel.addCustomersToAccountManager(
                                    customers: [user], 
                                    accountManagerId: accountManager.id
                                )
                                if success {
                                    dismiss()
                                }
                            }
                        }
                    } else {
                        // Pass selected customers and account manager
                        Task {
                            let success = await viewModel.addCustomersToAccountManager(
                                customers: selectedUsers, 
                                accountManagerId: user.id
                            )
                            if success {
                                dismiss()
                            }
                        }
                    }
                }
                .disabled(selectedUsers.isEmpty)
                .padding()
            }
        }
        .navigationTitle(viewModel.user?.role == .customer ? "Select Account Manager" : "Select Customers")
        .onAppear {
            Task {
                await viewModel.fetchUser(userId: userId)
            }
        }
    }
}

#Preview {
    NavigationView {
        UserAddRelationView(userId: "123")
    }
}
