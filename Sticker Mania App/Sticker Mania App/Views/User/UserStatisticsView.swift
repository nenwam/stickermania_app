//
//  UserStatisticsView.swift
//  Sticker Mania App
//
//  Created by Connor on 12/2/24.
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title2)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Text(value)
                .font(.title2)
                .bold()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct UserStatisticsView: View {
    @StateObject private var viewModel = UserStatisticsViewModel()
    @State private var userService = UserService()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image("sm_text_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 70)
                    .padding(.top)
                
                Text("Your Statistics")
                    .font(.title)
                    .bold()
                    .padding(.top)
                
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.error {
                    Text("Error loading statistics: \(error.localizedDescription)")
                        .foregroundColor(.red)
                } else {
                    VStack(spacing: 16) {
                        StatCard(
                            title: "Total Spent",
                            value: viewModel.formatCurrency(viewModel.totalSpent),
                            icon: "dollarsign.circle.fill",
                            iconColor: .green
                        )
                        StatCard(
                            title: "Delivered Orders",
                            value: "\(viewModel.completedOrdersCount)",
                            icon: "checkmark.circle.fill",
                            iconColor: .gray
                        )
                        StatCard(
                            title: "In Progress Orders",
                            value: "\(viewModel.inProgressOrdersCount)",
                            icon: "clock.fill",
                            iconColor: .orange
                        )
                        
                        // Most Ordered Items Card
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                Text("Most Ordered")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.bottom, 8)
                            
                            VStack(spacing: 8) {
                                ForEach(Array(viewModel.mostOrderedItems.prefix(3).enumerated()), id: \.element.name) { index, item in
                                    HStack {
                                        Text(item.name)
                                            .font(.callout)
                                        Spacer()
                                        Text("#\(index + 1)")
                                            .font(.callout)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemGray6))
        .task {
            print("DEBUG: Loading statistics")
            await viewModel.loadStatistics()
        }
    }
}

#Preview {
    UserStatisticsView()
}
