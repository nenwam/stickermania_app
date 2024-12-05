//
//  UserCreationView.swift
//  Sticker Mania App
//
//  Created by Connor on 12/3/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserCreationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole = UserRole.customer
    @State private var selectedBrands: [Brand] = []
    @State private var showingBrandPicker = false
    @State private var errorMessage = ""
    @State private var showError = false
    @StateObject private var viewModel = UserCreationViewModel()
    
    let roles = [UserRole.customer, UserRole.employee, UserRole.accountManager, UserRole.admin]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Information")) {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                }
                
                Section(header: Text("Role")) {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(roles, id: \.self) { role in
                            Text(role.rawValue.capitalized)
                                .tag(role)
                        }
                    }
                }
                
                if selectedRole == .customer {
                    Section(header: Text("Associated Brands")) {
                        ForEach(selectedBrands, id: \.id) { brand in
                            HStack {
                                Text("Name: \(brand.name)")
                                Spacer()
                                Text("ID: \(brand.id)")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                        Button("Select Brands") {
                            showingBrandPicker = true
                        }
                    }
                }
                
                Button("Create User") {
                    viewModel.createUser(name: name, 
                                       email: email, 
                                       password: password, 
                                       role: selectedRole,
                                       selectedBrands: Set(selectedBrands))
                    if !viewModel.showError {
                        dismiss()
                    }
                }
                .disabled(name.isEmpty || email.isEmpty || password.isEmpty)
            }
            .navigationTitle("Create New User")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $showingBrandPicker) {
                BrandSelectionView(selectedBrands: selectedBrands) { brands in
                    selectedBrands = brands
                }
            }
        }
    }
}

#Preview {
    UserCreationView()
}
