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
    private let logger = LoggingService.shared
    
    func createUser(name: String, email: String, password: String, role: UserRole, selectedBrands: Set<Brand>) {
        logger.log("Creating new user: \(name), email: \(email), role: \(role.rawValue), brands: \(selectedBrands.count)")
        
        // Get the current signed in user's auth token
        let currentUser = Auth.auth().currentUser
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.logger.log("Failed to create user auth account: \(error.localizedDescription)", level: .error)
                self?.errorMessage = error.localizedDescription
                self?.showError = true
                return
            }
            
            guard let authUser = result?.user else {
                self?.logger.log("Auth successful but user data unavailable", level: .error)
                self?.errorMessage = "Failed to create user"
                self?.showError = true
                return
            }
            
            self?.logger.log("Firebase Auth account created successfully with ID: \(authUser.uid)")
            
            // Create user document in Firestore
            let userData: [String: Any] = [
                "id": authUser.uid,
                "name": name,
                "email": email,
                "role": role.rawValue,
                "brands": selectedBrands.map { [
                    "id": $0.id,
                    "name": $0.name
                ] }
            ]
            
            self?.logger.log("Creating Firestore document for user")
            self?.db.collection("users").document(email).setData(userData) { [weak self] error in
                if let error = error {
                    self?.logger.log("Failed to create Firestore document: \(error.localizedDescription)", level: .error)
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                    return
                }
                
                self?.logger.log("User document created successfully in Firestore")
                
                // Sign back in as the original user if needed
                if let currentUser = currentUser {
                    self?.logger.log("Restoring original user session")
                    Auth.auth().updateCurrentUser(currentUser) { error in
                        if let error = error {
                            self?.logger.log("Failed to restore original user: \(error.localizedDescription)", level: .error)
                            self?.errorMessage = error.localizedDescription
                            self?.showError = true
                        } else {
                            self?.logger.log("Original user session restored successfully")
                        }
                    }
                } else {
                    self?.logger.log("User creation completed, no session restoration needed")
                }
            }
        }
    }
}
