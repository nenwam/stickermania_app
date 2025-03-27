//
//  UserDetailViewModel.swift
//  Sticker Mania App
//
//  Created by Connor on 11/26/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class UserDetailViewModel: ObservableObject {
    @Published var user: User?
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    private let logger = LoggingService.shared
    
    init() {
        logger.log("Initializing UserDetailViewModel")
        fetchCurrentUser()
    }
    
    private func fetchCurrentUser() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            logger.log("No authenticated user found", level: .warning)
            return 
        }
        
        logger.log("Fetching current user details for ID: \(currentUserId)")
        let userRef = db.collection("users").document(currentUserId)
        userRef.getDocument { [weak self] document, err in
            DispatchQueue.main.async {
                if let err = err {
                    self?.logger.log("Error fetching current user: \(err.localizedDescription)", level: .error)
                    self?.error = err.localizedDescription
                    return
                }
                
                guard let document = document, document.exists,
                      let data = document.data() else {
                    self?.logger.log("Current user document not found in Firestore", level: .error)
                    self?.error = "Current user not found"
                    return
                }
                
                // Parse brands data
                let brandsData = data["brands"] as? [[String: Any]] ?? []
                let brands = brandsData.compactMap { brandData -> Brand? in
                    guard let id = brandData["id"] as? String,
                          let name = brandData["name"] as? String else {
                        self?.logger.log("Invalid brand data in user document", level: .warning)
                        return nil
                    }
                    return Brand(id: id, name: name)
                }
                
                self?.logger.log("Parsed \(brands.count) brands for current user")
                
                // Get profile picture URL if it exists
                let profilePictureUrl = data["profilePictureUrl"] as? String
                
                let email = data["email"] as? String ?? ""
                let name = data["name"] as? String ?? ""
                let role = UserRole(rawValue: data["role"] as? String ?? "") ?? .customer
                
                // Create user object
                let user = User(
                    id: document.documentID,
                    email: email,
                    name: name,                    
                    role: role,
                    brands: brands,
                    profilePictureUrl: profilePictureUrl,
                    userRelationIds: nil
                )
                
                self?.logger.log("Successfully fetched current user: \(name) (\(email)), role: \(role.rawValue)")
                self?.currentUser = user
            }
        }
    }
    
    func fetchUser(userId: String) {
        logger.log("Fetching user details for ID: \(userId)")
        isLoading = true
        error = nil
        
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { [weak self] document, err in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let err = err {
                    self?.logger.log("Error fetching user: \(err.localizedDescription)", level: .error)
                    self?.error = err.localizedDescription
                    return
                }
                
                guard let document = document, document.exists,
                      let data = document.data() else {
                    self?.logger.log("User document not found in Firestore", level: .error)
                    self?.error = "User not found"
                    return
                }
                
                // Parse brands data
                let brandsData = data["brands"] as? [[String: Any]] ?? []
                let brands = brandsData.compactMap { brandData -> Brand? in
                    guard let id = brandData["id"] as? String,
                          let name = brandData["name"] as? String else {
                        self?.logger.log("Invalid brand data in user document", level: .warning)
                        return nil
                    }
                    return Brand(id: id, name: name)
                }
                
                self?.logger.log("Parsed \(brands.count) brands for user")
                
                // Get profile picture URL if it exists
                let profilePictureUrl = data["profilePictureUrl"] as? String
                
                let email = data["email"] as? String ?? ""
                let name = data["name"] as? String ?? ""
                let role = UserRole(rawValue: data["role"] as? String ?? "") ?? .customer
                
                // Create user object
                let user = User(
                    id: document.documentID,
                    email: email,
                    name: name,                    
                    role: role,
                    brands: brands,
                    profilePictureUrl: profilePictureUrl,
                    userRelationIds: nil
                )
                
                self?.logger.log("Successfully fetched user: \(name) (\(email)), role: \(role.rawValue)")
                self?.user = user
            }
        }
    }
    
    func updateBrands(brands: [Brand]) {
        guard let userId = user?.id else { 
            logger.log("Cannot update brands: No user ID available", level: .error)
            return 
        }
        
        logger.log("Updating brands for user \(userId) with \(brands.count) brands")
        isLoading = true
        error = nil
        
        // Convert brands to dictionary format for Firestore
        let brandsData = brands.map { [
            "id": $0.id,
            "name": $0.name
        ] }
        
        let userRef = db.collection("users").document(userId)
        userRef.updateData([
            "brands": brandsData
        ]) { [weak self] err in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let err = err {
                    self?.logger.log("Error updating brands: \(err.localizedDescription)", level: .error)
                    self?.error = err.localizedDescription
                    return
                }
                
                self?.logger.log("Successfully updated brands for user \(userId)")
                // Update local user object with new brands
                self?.user?.brands = brands
            }
        }
    }
    
    func updateRole(to newRole: UserRole) {
        guard let userId = user?.id else { 
            logger.log("Cannot update role: No user ID available", level: .error)
            return 
        }
        
        logger.log("Updating role for user \(userId) to \(newRole.rawValue)")
        isLoading = true
        error = nil
        
        let userRef = db.collection("users").document(userId)
        userRef.updateData([
            "role": newRole.rawValue
        ]) { [weak self] err in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let err = err {
                    self?.logger.log("Error updating role: \(err.localizedDescription)", level: .error)
                    self?.error = err.localizedDescription
                    return
                }
                
                self?.logger.log("Successfully updated role for user \(userId) to \(newRole.rawValue)")
                // Update local user object with new role
                self?.user?.role = newRole
            }
        }
    }
}
