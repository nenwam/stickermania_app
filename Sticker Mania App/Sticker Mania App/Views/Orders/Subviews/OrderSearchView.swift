//
//  OrderSearchView.swift
//  Sticker Mania App
//
//  Created by Connor on 12/2/24.
//

import SwiftUI

struct OrderSearchView: View {
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
                    NavigationLink(destination: OrderListView(customerId: user.email)) {
                        HStack {
                            AsyncImage(url: URL(string: user.profilePictureUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
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
        }
    }
}

#Preview {
    NavigationView {
        OrderSearchView()
    }
}
