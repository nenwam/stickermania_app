//
//  OrderSearchView.swift
//  Sticker Mania App
//
//  Created by Connor on 12/2/24.
//

import SwiftUI

struct OrderSearchView: View {
    @State private var searchText = ""
    @StateObject private var viewModel = OrderSearchViewModel()
    @State private var isRefreshing = false
    
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
            
            if searchText.isEmpty {
                // Recent orders section
                VStack(alignment: .leading) {
                    HStack {
                        Text("Recent Orders")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            isRefreshing = true
                            viewModel.fetchRecentOrders()
                            
                            // Rotate for 1 second, then stop
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                isRefreshing = false
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.headline)
                                .rotationEffect(Angle(degrees: isRefreshing ? 360 : 0))
                                .animation(isRefreshing ? Animation.linear(duration: 1.0).repeatCount(1, autoreverses: false) : .default, value: isRefreshing)
                                .padding(.trailing, 5)
                        }
                        .disabled(viewModel.isLoading || isRefreshing)
                    }
                    .padding(.horizontal)
                    .padding(.top, 40)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if viewModel.recentOrders.isEmpty {
                        Text("No recent orders found")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List(viewModel.recentOrders, id: \.id) { order in
                            NavigationLink(destination: OrderDetailView(order: order)) {
                                VStack(alignment: .leading) {
                                    // TODO: Customer name, brand name, email, order total
                                    Text(order.customerName ?? order.brandName)
                                        .font(.headline)

                                    Text(order.brandName)
                                        .font(.subheadline)
                                    
                                    HStack {
                                        Text(order.customerEmail)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        
                                        Spacer()
                                        
                                        Text(order.createdAt, style: .date)
                                            .font(.caption)
                                    }
                                    
                                    HStack {
                                        Text("$\(order.totalAmount, specifier: "%.2f")")
                                            .fontWeight(.semibold)
                                        
                                        Spacer()
                                        
                                        Text(order.status.rawValue.capitalized == "Inprogress" ? "In Progress" : order.status.rawValue.capitalized)
                                            .font(.caption)
                                            .padding(4)
                                            .background(statusColor(for: order.status))
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    
                }
            } else {
                // Search results
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
            }
        }
        .onAppear {
            viewModel.fetchRecentOrders()
        }
    }
    
    private func statusColor(for status: OrderStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .flagged:
            return .red
        }
    }
}

#Preview {
    NavigationView {
        OrderSearchView()
    }
}
