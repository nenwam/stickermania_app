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
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                ChatListView()
                    .navigationTitle("Messages")
            }
            .tabItem {
                Label("Messages", systemImage: "message")
            }
            .tag(0)
            
            NavigationView {
                OrderListView(customerId: Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? "")
                    .navigationTitle("My Orders")
            }
            .tabItem {
                Label("Orders", systemImage: "doc.text")
            }
            .tag(1)
            
            Button(action: {
                AuthenticationService.shared.signOut { _ in }
            }) {
                VStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("Sign Out")
                    if let email = Auth.auth().currentUser?.email {
                        Text(email.components(separatedBy: "@").first ?? "")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .tabItem {
                Label("Account", systemImage: "person.circle")
            }
            .tag(2)
        }
    }
}

#Preview {
    CustomerHomeView()
}
