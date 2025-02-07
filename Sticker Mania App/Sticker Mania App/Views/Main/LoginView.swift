//
//  LoginView.swift
//  Sticker Mania App
//
//  Created by Connor on 11/7/24.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSigningUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSafariView = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        Image("sm_text_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .padding(.bottom, 30)
                        
                        HStack(alignment: .top, spacing: 20) {
                            // Authentication Section
                            VStack(spacing: 15) {
                                if isSigningUp {
                                    TextField("Name", text: $name)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .textInputAutocapitalization(.words)
                                }
                                
                                TextField("Email", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                
                                SecureField("Password", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: {
                                    if isSigningUp {
                                        handleSignUp()
                                    } else {
                                        handleSignIn()
                                    }
                                }) {
                                    Text(isSigningUp ? "Sign Up" : "Sign In")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    showSafariView = true
                                }) {
                                    Text("Request Access")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.top, 10)
                                }
                                .sheet(isPresented: $showSafariView) {
                                    SafariView(url: URL(string: "https://docs.google.com/forms/d/e/1FAIpQLScKVr_q1tIFNFPrukWurlXIf4QAhwPjyZPc6SMaiJwN7VxtmQ/viewform?usp=header")!)
                                }
                            }
                            .frame(maxWidth: geometry.size.width > 800 ? geometry.size.width / 2.5 : .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Information Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("About Sticker Mania")
                                .font(.title2)
                                .bold()
                            
                            if geometry.size.width > 800 {
                                // iPad layout - 2 columns
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 20) {
                                    InfoSections()
                                }
                            } else {
                                // iPhone layout - single column
                                InfoSections()
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .alert("Error", isPresented: $showError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func handleSignIn() {
        AuthenticationService.shared.signIn(email: email, password: password) { result in
            switch result {
            case .success(_):
                // Sign in successful - navigation handled by app root view
                break
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func handleSignUp() {
        AuthenticationService.shared.signUp(email: email, password: password, name: name) { result in
            switch result {
            case .success(_):
                // Sign up successful - navigation handled by app root view
                break
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// Move InfoSections to a separate view for better organization
struct InfoSections: View {
    var body: some View {
        Group {
            InfoSection(title: "Who We Are",
                       content: "Sticker Mania is a leading digital sticker creation and distribution platform. Our mission is to bring creativity and expression to physical products.")
            
            InfoSection(title: "What We Offer",
                       content: "• Custom sticker application orders\n• Extensive sticker and bag library\n• Regular content updates\n• Ability to chat with account managers")
            
            InfoSection(title: "App Features",
                       content: "• Create Sticker Mania orders\n• Track order progress\n• Chat with the production team\n• View Sticker Mania order statistics")
            
            InfoSection(title: "Getting Started",
                       content: "You can explore our list of products below without an account. Request access to unlock full creation and messaging capabilities!")
            
            InfoSection(title: "Products",
                       content: "• Eighth Bags\n• QP Bags\n• Custom Stickers\n• Pre-designed Stickers")
        }
    }
}

struct InfoSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    LoginView()
}
