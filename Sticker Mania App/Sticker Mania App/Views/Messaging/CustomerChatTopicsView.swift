//
//  CustomerChatTopicsView.swift
//  Sticker Mania App
//
//  Created by Connor on 4/18/25.
//

import SwiftUI

struct CustomerChatTopicsView: View {
    // Instantiate the ViewModel
    @StateObject private var viewModel = CustomerChatTopicsViewModel()

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.0)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 370)
                    .background(Color.clear)
            } else if let error = viewModel.error {
                Text("Error loading chats: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, minHeight: 370)
                    .padding()  
            } else if viewModel.customerTopicInfos.isEmpty {
                Text("No customer chats found.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 370)
                    .padding()
            } else {
                List {
                    ForEach(viewModel.customerTopicInfos) { topicInfo in
                        NavigationLink(destination: CustomerChatListView(customerId: topicInfo.user.email)) {
                            ChatRowView(user: topicInfo.user, hasUnreadMessages: topicInfo.hasUnreadMessages)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    // Use the force refresh method instead
                    viewModel.forceRefreshCustomerChats()
                }
            }
        }
        .onAppear {
            // Only fetch if we don't have data yet - this prevents refreshing when returning from ChatDetailView
            // if viewModel.customerTopicInfos.isEmpty && !viewModel.isLoading {
                viewModel.forceRefreshCustomerChats()
            // }
        }
    }
}

#Preview {
    CustomerChatTopicsView()
    // You might want to inject a preview ViewModel with dummy data here
    // for better preview experience, similar to how it was done for ChatRowView.
}
