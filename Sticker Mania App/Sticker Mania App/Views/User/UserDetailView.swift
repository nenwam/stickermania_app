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
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
            } else if let user = viewModel.user {
                VStack(spacing: 20) {
                    // Profile Image
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.gray)
                        .padding(.top)
                    
                    // User Info
                    VStack(spacing: 12) {
                        Text(user.name)
                            .font(.title)
                            .bold()
                        
                        Text("ID: \(user.id)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Role: \(user.role.rawValue.capitalized)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Brands Section
                    if let brands = user.brands {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Associated Brands")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    showingBrandEditor = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundColor(.blue)
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
                        .sheet(isPresented: $showingBrandEditor) {
                            NavigationView {
                                BrandSelectionView(selectedBrands: user.brands ?? [], onSave: { updatedBrands in
                                    viewModel.updateBrands(brands: updatedBrands)
                                })
                                .navigationTitle("Edit Brands")
                                .navigationBarItems(
                                    leading: Button("Cancel") {
                                        showingBrandEditor = false
                                    },
                                    trailing: Button("Save") {
                                        showingBrandEditor = false
                                    }
                                )
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
