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
    @State private var selectedChatId: String? = nil
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
                        ChatListView(selectedChatId: $selectedChatId)
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
        }
        .onAppear {
            // Set up notification observer for chat messages
            NotificationCenter.default.addObserver(
                forName: Notification.Name("OpenChat"),
                object: nil,
                queue: .main
            ) { notification in
                if let chatId = notification.userInfo?["chatId"] as? String {
                    print("CustomerHomeView: Received notification to open chat: \(chatId)")
                    
                    // First set the selectedChatId
                    self.selectedChatId = chatId
                    
                    // Then switch to messages tab with a slight delay
                    // This ensures the chat list view is ready to handle the navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.selectedTab = 0
                        print("CustomerHomeView: Switched to messages tab (tab 0) for chat: \(chatId)")
                    }
                }
            }
            
            // Get user role
            Task {
                if let email = Auth.auth().currentUser?.email {
                    do {
                        userRole = try await userService.getUserRole(email: email)
                    } catch {
                        print("Error fetching user role: \(error)")
                    }
                }
            }
        }
        .onDisappear {
            // Remove observer when view disappears
            NotificationCenter.default.removeObserver(self, name: Notification.Name("OpenChat"), object: nil)
        }
    }
}

#Preview {
    CustomerHomeView()
}
