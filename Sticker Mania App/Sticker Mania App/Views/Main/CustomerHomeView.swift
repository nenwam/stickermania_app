//
//  CustomerHomeView.swift
//  Sticker Mania App
//
//  Created by Connor on 11/7/24.
//

import SwiftUI
import FirebaseAuth

struct CustomerHomeView: View {
    @State private var selectedTab = 0
    @State private var userRole: UserRole?
    private let userService = UserService()
    
    var body: some View {
        VStack(spacing: 0) {
            Image("sm_dice_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 40)
                .padding(.vertical, 2)
            
            TabView(selection: $selectedTab) {
                NavigationView {
                    if userRole == .suspended {
                        SuspendedView()
                    } else {
                        ChatListView()
                    }
                }
                .tabItem {
                    Label("Messages", systemImage: "message")
                }
                .tag(0)
                
                NavigationView {
                    if userRole == .suspended {
                        SuspendedView()
                    } else {
                        OrderListView(customerId: Auth.auth().currentUser?.email ?? "")
                            .navigationTitle("My Orders")
                    }
                }
                .tabItem {
                    Label("Orders", systemImage: "doc.text")
                }
                .tag(1)
                
                NavigationView {
                    if userRole == .suspended {
                        SuspendedView()
                    } else {
                        UserProfileView()
                    }
                }
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(2)
            }
            .onChange(of: selectedTab) { _ in
                if let email = Auth.auth().currentUser?.email {
                    userService.fetchUserRole(email: email) { result in
                        switch result {
                        case .success(let role):
                            DispatchQueue.main.async {
                                userRole = role
                            }
                        case .failure(let error):
                            print("Error fetching user role: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .onAppear {
                if let email = Auth.auth().currentUser?.email {
                    userService.fetchUserRole(email: email) { result in
                        switch result {
                        case .success(let role):
                            DispatchQueue.main.async {
                                userRole = role
                            }
                        case .failure(let error):
                            print("Error fetching user role: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CustomerHomeView()
}
