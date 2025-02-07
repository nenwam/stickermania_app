//
//  UserProfileView.swift
//  Sticker Mania App
//
//  Created by Connor on 12/2/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PhotosUI

struct UserProfileView: View {
    @State private var user: User?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var showingUsernameAlert = false
    @State private var showingPasswordAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingImageAlert = false
    @StateObject private var viewModel = UserProfileViewModel()
    @State private var showingUserCreation = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error = error {
                VStack {
                    Text("Error loading profile")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            } else if let user = user {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Profile Picture Section
                        VStack(alignment: .center, spacing: 10) {
                            if let profileImageUrl = viewModel.profileImageUrl,
                               let url = URL(string: profileImageUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 120, height: 120)
                                }
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 120, height: 120)
                            }
                            
                            PhotosPicker(selection: $selectedItem,
                                       matching: .images) {
                                Text(viewModel.profileImageUrl == nil ? "Upload Picture" : "Change Picture")
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .onChange(of: selectedItem) { newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    viewModel.uploadProfilePicture(image: image) { result in
                                        switch result {
                                        case .success:
                                            alertMessage = "Profile picture updated successfully"
                                            isSuccess = true
                                        case .failure(let error):
                                            alertMessage = error.localizedDescription
                                            isSuccess = false
                                        }
                                        showingImageAlert = true
                                    }
                                }
                            }
                        }
                        
                        // User info section
                        VStack(alignment: .leading) {
                            Text(user.name)
                                .font(.title)
                                .bold()
                            Text("Email: \(user.email)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        
                        // Create User button - only show for admin
                        if user.role == .admin {
                            NavigationLink(destination: UserCreationView()) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                            .font(.title2)
                                        Text("Create New User")
                                            .font(.headline)
                                    }
                                    Text("Add a new user to the system")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 2)
                            }
                        }

                        
                        
                        // Associated Brands section - only show for customers
                        if user.role == .customer {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Your Brands")
                                    .font(.headline)
                                
                                if let brands = user.brands {
                                    if brands.isEmpty {
                                        Text("No brands associated")
                                            .foregroundColor(.secondary)
                                    } else {
                                        ForEach(brands, id: \.id) { brand in
                                            HStack {
                                                Text(brand.name)
                                                    .font(.body)
                                                Spacer()
                                            }
                                            .padding()
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                } else {
                                    Text("No brands associated")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                        }
                        
                        // Orders section - only show for customers
                        if user.role == .customer {
                            NavigationLink(destination: OrderListView(customerId: user.email)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .font(.title2)
                                        Text("View Orders")
                                            .font(.headline)
                                    }
                                    Text("Check your order history")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 2)
                            }
                            
                            // Statistics section
                            NavigationLink(destination: UserStatisticsView()) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "chart.bar")
                                            .font(.title2)
                                        Text("View Statistics")
                                            .font(.headline)
                                    }
                                    Text("See your order analytics")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 2)
                            }
                        }

                        // Username change section
                        // VStack(alignment: .leading, spacing: 10) {
                        //     Text("Change Username")
                        //         .font(.headline)
                            
                        //     TextField("New username", text: $newUsername)
                        //         .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                        //     Button("Update Username") {
                        //         viewModel.changeUsername(to: newUsername) { result in
                        //             switch result {
                        //             case .success:
                        //                 alertMessage = "Username updated successfully"
                        //                 isSuccess = true
                        //             case .failure(let error):
                        //                 alertMessage = error.localizedDescription
                        //                 isSuccess = false
                        //             }
                        //             showingUsernameAlert = true
                        //         }
                        //     }
                        //     .buttonStyle(.borderedProminent)
                        // }
                        // .padding()
                        // .background(Color(.systemBackground))
                        // .cornerRadius(10)
                        // .shadow(radius: 2)
                        
                        // Password change section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Change Password")
                                .font(.headline)
                            
                            SecureField("New password", text: $newPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Update Password") {
                                viewModel.changePassword(to: newPassword) { result in
                                    switch result {
                                    case .success:
                                        alertMessage = "Password updated successfully"
                                        isSuccess = true
                                    case .failure(let error):
                                        alertMessage = error.localizedDescription
                                        isSuccess = false
                                    }
                                    showingPasswordAlert = true
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)

                        // Logout button
                        Button(action: {
                            AuthenticationService.shared.signOut { _ in }
                        }) {
                            HStack {
                                Text("Sign Out")
                                    .foregroundColor(.red)
                                Spacer()
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                        }
                    }
                    .padding()
                }
            } else {
                Text("User not found")
            }
        }
        .task {
            await loadUserProfile()
        }
        .alert("Username Update", isPresented: $showingUsernameAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .alert("Password Update", isPresented: $showingPasswordAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .alert("Profile Picture Update", isPresented: $showingImageAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadUserProfile() async {
        guard let currentUser = Auth.auth().currentUser,
              let email = currentUser.email else {
            error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
            isLoading = false
            return
        }
        
        do {
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(email).getDocument()
            
            if let userData = userDoc.data() {
                let roleString = userData["role"] as? String ?? "customer"
                let userRole = UserRole(rawValue: roleString) ?? .customer
                
                // Parse brands data
                var brands: [Brand] = []
                if let brandsData = userData["brands"] as? [[String: Any]] {
                    brands = brandsData.compactMap { brandData in
                        guard let id = brandData["id"] as? String,
                              let name = brandData["name"] as? String else {
                            return nil
                        }
                        return Brand(id: id, name: name)
                    }
                }
                
                self.user = User(
                    id: userData["id"] as? String ?? "",
                    email: email,
                    name: userData["name"] as? String ?? "Unknown",
                    role: userRole,
                    brands: brands
                )
                
                // Set profile image URL if it exists
                if let profilePictureUrl = userData["profilePictureUrl"] as? String {
                    viewModel.profileImageUrl = profilePictureUrl
                }
            } else {
                error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User data not found"])
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationView {
        UserProfileView()
    }
}
