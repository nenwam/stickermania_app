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
    @Published var associatedCustomers: [(id: String, email: String, name: String)] = []
    
    private let db = Firestore.firestore()
    private let logger = LoggingService.shared
    
    init() {
        logger.log("Initializing UserDetailViewModel")
        fetchCurrentUser()
    }
    
    private func fetchCurrentUser() {
        guard let currentUserId = Auth.auth().currentUser?.email else { 
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
                
                // Get customer IDs for account managers
                let customerIds = data["customerIds"] as? [String] ?? []
                
                // Create user object
                let user = User(
                    id: document.documentID,
                    email: email,
                    name: name,                    
                    role: role,
                    brands: brands,
                    profilePictureUrl: profilePictureUrl,
                    userRelationIds: customerIds
                )
                
                self?.logger.log("Successfully fetched user: \(name) (\(email)), role: \(role.rawValue)")
                self?.user = user
                
                // If this is an account manager, fetch their associated customers
                if role == .accountManager && !customerIds.isEmpty {
                    self?.fetchAssociatedCustomers(customerIds: customerIds)
                }
            }
        }
    }
    
    func fetchAssociatedCustomers(customerIds: [String]) {
        logger.log("Fetching associated customers for account manager")
        isLoading = true
        
        // Reset the current list
        self.associatedCustomers = []
        
        let group = DispatchGroup()
        
        for customerId in customerIds {
            group.enter()
            
            let customerRef = db.collection("users").document(customerId)
            customerRef.getDocument { [weak self] document, err in
                defer { group.leave() }
                
                if let err = err {
                    self?.logger.log("Error fetching customer \(customerId): \(err.localizedDescription)", level: .error)
                    return
                }
                
                guard let document = document, document.exists,
                      let data = document.data() else {
                    self?.logger.log("Customer document not found: \(customerId)", level: .warning)
                    return
                }
                
                let email = data["email"] as? String ?? ""
                let name = data["name"] as? String ?? "Unknown Customer"
                
                DispatchQueue.main.async {
                    self?.associatedCustomers.append((id: customerId, email: email, name: name))
                    self?.logger.log("Added customer to list: \(name) (\(email))")
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            self?.logger.log("Finished loading \(self?.associatedCustomers.count ?? 0) associated customers")
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

    func deleteUser(completion: @escaping (Bool, String?) -> Void) {
        guard let userIdToDelete = user?.id else {
            logger.log("Cannot delete user: No user ID available", level: .error)
            completion(false, "User ID not found.")
            return
        }

        guard let currentUserId = Auth.auth().currentUser?.uid, currentUserId != userIdToDelete else {
            logger.log("Attempted to delete self. This should be handled by account deletion flow.", level: .warning)
            completion(false, "Cannot delete your own account from here.")
            return
        }

        // Check if the current user is an admin - Ideally, this check should also happen server-side
        // For now, we rely on the client-side check which might not be secure.
        guard currentUser?.role == .admin else {
            logger.log("Unauthorized attempt to delete user \(userIdToDelete) by user \(currentUserId)", level: .warning)
            completion(false, "You do not have permission to delete users.")
            return
        }

        logger.log("Attempting to delete user \(userIdToDelete)")
        isLoading = true
        error = nil

        let userRef = db.collection("users").document(userIdToDelete)

        // 1. Delete Firestore Document
        userRef.delete { [weak self] err in
            DispatchQueue.main.async {
                if let err = err {
                    self?.logger.log("Error deleting Firestore user document \(userIdToDelete): \(err.localizedDescription)", level: .error)
                    self?.isLoading = false
                    self?.error = "Failed to delete user data: \(err.localizedDescription)"
                    completion(false, self?.error)
                    return
                }

                self?.logger.log("Successfully deleted Firestore user document \(userIdToDelete)")

                // 2. Trigger Backend for Auth Deletion (Placeholder)
                // !! IMPORTANT !!
                // Deleting from Firebase Authentication MUST be done server-side (e.g., Cloud Function)
                // Call your backend function here to delete the user from Firebase Auth using the Admin SDK.
                // Example: self?.triggerCloudFunctionToDeleteAuthUser(userId: userIdToDelete) { success, authError in ... }
                // For now, we'll assume success on the client side after Firestore deletion.
                // Proper implementation requires backend interaction.

                self?.logger.log("Firestore document deleted. Auth deletion must be handled by backend for user \(userIdToDelete).")
                self?.isLoading = false
                self?.user = nil // Clear the user data locally
                completion(true, nil)
            }
        }
    }
    
    // Placeholder for triggering a backend function
    // private func triggerCloudFunctionToDeleteAuthUser(userId: String, completion: @escaping (Bool, String?) -> Void) {
    //    // Implementation to call your HTTPS Cloud Function would go here
    //    logger.log("Placeholder: Triggering backend function to delete Firebase Auth user \(userId)", level: .info)
    //    // Simulate backend call success for now
    //    completion(true, nil)
    // }
}
