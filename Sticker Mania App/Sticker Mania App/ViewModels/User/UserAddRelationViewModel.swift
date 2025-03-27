//
//  UserAddRelationViewModel.swift
//  Sticker Mania App
//
//  Created by Connor on 12/19/24.
//

import Foundation
import FirebaseFirestore

@MainActor
class UserAddRelationViewModel: ObservableObject {
    private let db = Firestore.firestore()
    private let logger = LoggingService.shared
    @Published var user: User?
    @Published var filteredUsers: [User] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func fetchUser(userId: String) async {
        logger.log("Fetching user details for ID: \(userId)")
        isLoading = true
        do {
            let docRef = db.collection("users").document(userId)
            let document = try await docRef.getDocument()
            
            guard let data = document.data() else {
                let errorMessage = "User not found"
                logger.log(errorMessage, level: .error)
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            // Parse brands if they exist
            var brands: [Brand]?
            if let brandsData = data["brands"] as? [[String: Any]] {
                brands = brandsData.map { brandData in
                    Brand(
                        id: brandData["id"] as? String ?? "",
                        name: brandData["name"] as? String ?? ""
                    )
                }
                logger.log("Parsed \(brands?.count ?? 0) brands for user")
            }
            
            let userEmail = data["email"] as? String ?? ""
            let userName = data["name"] as? String ?? ""
            let userRole = UserRole(rawValue: data["role"] as? String ?? "") ?? .customer
            
            self.user = User(
                id: document.documentID,
                email: userEmail,
                name: userName,
                role: userRole,
                brands: brands,
                profilePictureUrl: data["profilePictureUrl"] as? String,
                userRelationIds: nil
            )
            
            logger.log("Successfully fetched user: \(userName) (\(userEmail)), role: \(userRole.rawValue)")
        } catch {
            logger.log("Error fetching user: \(error.localizedDescription)", level: .error)
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func searchUsers(matching query: String, role: UserRole) async {
        guard !query.isEmpty else {
            logger.log("Empty search query, clearing results")
            self.filteredUsers = []
            return
        }
        
        logger.log("Searching for users with role \(role.rawValue) matching: \(query)")
        isLoading = true
        do {
            let querySnapshot = try await db.collection("users")
                .whereField("role", isEqualTo: role.rawValue)
                .whereField("name", isGreaterThanOrEqualTo: query)
                .whereField("name", isLessThanOrEqualTo: query + "\u{f8ff}")
                .getDocuments()
            
            logger.log("Query returned \(querySnapshot.documents.count) results")
            var matchedUsers: [User] = []
            
            for document in querySnapshot.documents {
                let data = document.data()
                
                var brands: [Brand]?
                if let brandsData = data["brands"] as? [[String: Any]] {
                    brands = brandsData.compactMap { brandData in
                        guard let id = brandData["id"] as? String,
                              let name = brandData["name"] as? String else {
                            logger.log("Invalid brand data in user document", level: .warning)
                            return nil
                        }
                        return Brand(id: id, name: name)
                    }
                }
                
                let email = data["email"] as? String ?? ""
                let name = data["name"] as? String ?? ""
                
                let user = User(
                    id: document.documentID,
                    email: email,
                    name: name,
                    role: UserRole(rawValue: data["role"] as? String ?? "") ?? .customer,
                    brands: brands,
                    profilePictureUrl: data["profilePictureUrl"] as? String,
                    userRelationIds: nil
                )
                matchedUsers.append(user)
                logger.log("Found matching user: \(name) (\(email))")
            }
            
            self.filteredUsers = matchedUsers
            logger.log("Updated UI with \(matchedUsers.count) matching users")
        } catch {
            logger.log("Search error: \(error.localizedDescription)", level: .error)
            self.error = error.localizedDescription
            self.filteredUsers = []
        }
        isLoading = false
    }
    
    func addCustomersToAccountManager(customers: [User], accountManagerId: String) async -> Bool {
        logger.log("Adding \(customers.count) customers to account manager: \(accountManagerId)")
        isLoading = true
        do {
            let accountManagerDoc = try await db.collection("users").document(accountManagerId).getDocument()
            
            // Use UIDs for customer relationships
            var existingCustomerIds = accountManagerDoc.data()?["customerIds"] as? [String] ?? []
            logger.log("Account manager has \(existingCustomerIds.count) existing customer IDs")
            
            // Use customer UIDs instead of emails
            let newCustomerIds = customers.map { $0.id } // This will now have UIDs
            existingCustomerIds.append(contentsOf: newCustomerIds)
            let uniqueCustomerIds = Array(Set(existingCustomerIds))
            
            // Also keep the old relationship mapping for compatibility
            var existingCustomerEmails = accountManagerDoc.data()?["customerEmails"] as? [String] ?? []
            let newCustomerEmails = customers.map { $0.email }
            existingCustomerEmails.append(contentsOf: newCustomerEmails)
            let uniqueCustomerEmails = Array(Set(existingCustomerEmails))
            
            logger.log("Updating account manager with \(uniqueCustomerIds.count) customer IDs and \(uniqueCustomerEmails.count) customer emails")
            
            // Update with both fields
            try await db.collection("users").document(accountManagerId).updateData([
                "customerIds": uniqueCustomerIds,
                "customerEmails": uniqueCustomerEmails
            ])
            
            logger.log("Successfully updated account manager relationships")
            isLoading = false
            return true
        } catch {
            logger.log("Failed to add customers to account manager: \(error.localizedDescription)", level: .error)
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }
}
