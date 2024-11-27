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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Sticker Mania")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 30)

                // Image("sm_logo_nobg")
                //     .resizable()
                //     .scaledToFit()
                //     .frame(height: 100)
                
                if isSigningUp {
                    TextField("Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                }
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
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
                
                Button(action: { isSigningUp.toggle() }) {
                    Text(isSigningUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
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

#Preview {
    LoginView()
}
