//
//  UserDetail.swift
//  Sticker Mania App
//
//  Created by Connor on 11/26/24.
//

import SwiftUI

struct UserDetailView: View {
    let userId: String
    @StateObject private var viewModel = UserDetailViewModel()
    @State private var showingBrandEditor = false
    @State private var showingRoleEditor = false
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
            } else if let user = viewModel.user {
                VStack(spacing: 20) {
                    // Profile Image
                    Group {
                        if let profileImageUrl = user.profilePictureUrl,
                           let url = URL(string: profileImageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top)
                    
                    // User Info
                    VStack(spacing: 12) {
                        Text(user.name)
                            .font(.title)
                            .bold()
                        
                        Text("ID: \(user.id)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Role: \(user.role.rawValue.capitalized)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                                Button(action: {
                                    showingRoleEditor = true
                                }) {
                                    Image(systemName: "pencil.circle")
                                        .foregroundColor(.blue)
                                }
                                .sheet(isPresented: $showingRoleEditor) {
                                    RoleSelectionView(currentRole: user.role) { newRole in
                                        viewModel.updateRole(to: newRole)
                                        showingRoleEditor = false
                                    }
                                }
                            
                        }
                    }
                    
                    // Associated Customers Section (only for account managers)
                    if user.role == .accountManager {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Associated Customers")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if viewModel.associatedCustomers.isEmpty {
                                Text("No customers assigned")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(viewModel.associatedCustomers, id: \.id) { customer in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(customer.name)
                                                .font(.body)
                                            Text(customer.email)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        
                                        NavigationLink(destination: UserDetailView(userId: customer.id)) {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }

                    // Create User button - only show for admin
                    
                    NavigationLink(destination: UserAddRelationView(userId: user.id)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .font(.title2)
                                Text((user.role == .accountManager || user.role == .admin ? "Add Customer" : "Add Account Manager"))
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
                    
                    
                    // Brands Section
                    if let brands = user.brands {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Associated Brands")
                                    .font(.headline)
                                Spacer()
                                NavigationLink(isActive: $showingBrandEditor) {
                                    BrandSelectionView(selectedBrands: user.brands ?? [], onSave: { updatedBrands in
                                        viewModel.updateBrands(brands: updatedBrands)
                                        showingBrandEditor = false
                                    })
                                    .navigationTitle("Edit Brands")
                                } label: {
                                    EditBrandsButton(onEdit: {
                                        showingBrandEditor = true
                                    })
                                }
                            }
                            .padding(.horizontal)
                            
                            if brands.isEmpty {
                                Text("No brands associated")
                                    .foregroundColor(.secondary)
                                    .padding()
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
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
            } else if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("User Details")
        .onAppear {
            viewModel.fetchUser(userId: userId)
        }
    }
}

#Preview {
    NavigationView {
        UserDetailView(userId: "123")
    }
}
