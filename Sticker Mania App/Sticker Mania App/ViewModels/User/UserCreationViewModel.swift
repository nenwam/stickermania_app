//
//  UserCreationViewModel.swift
//  Sticker Mania App
//
//  Created by Connor on 12/3/24.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class UserCreationViewModel: ObservableObject {
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let db = Firestore.firestore()
    
    func createUser(name: String, email: String, password: String, role: UserRole, selectedBrands: Set<Brand>) {
        // Get the current signed in user's auth token
        let currentUser = Auth.auth().currentUser
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                self?.showError = true
                return
            }
            
            guard let _ = result?.user else {
                self?.errorMessage = "Failed to create user"
                self?.showError = true
                return
            }
            
            // Create user document in Firestore
            let userData: [String: Any] = [
                "id": email,
                "name": name,
                "email": email,
                "role": role.rawValue,
                "brands": selectedBrands.map { [
                    "id": $0.id,
                    "name": $0.name
                ] }
            ]
            
            self?.db.collection("users").document(email).setData(userData) { error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                    return
                }
                
                // Sign back in as the original user if needed
                if let currentUser = currentUser {
                    Auth.auth().updateCurrentUser(currentUser) { error in
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                            self?.showError = true
                        }
                    }
                }
            }
        }
    }
}
