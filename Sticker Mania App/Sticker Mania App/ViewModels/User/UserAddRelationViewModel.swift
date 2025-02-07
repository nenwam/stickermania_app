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
    @Published var user: User?
    @Published var filteredUsers: [User] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func fetchUser(userId: String) async {
        isLoading = true
        do {
            let docRef = db.collection("users").document(userId)
            let document = try await docRef.getDocument()
            
            guard let data = document.data() else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
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
            }
            
            self.user = User(
                id: document.documentID,
                email: data["email"] as? String ?? "",
                name: data["name"] as? String ?? "",
                role: UserRole(rawValue: data["role"] as? String ?? "") ?? .customer,
                brands: brands,
                profilePictureUrl: data["profilePictureUrl"] as? String
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func searchUsers(matching query: String, role: UserRole) async {
        guard !query.isEmpty else {
            self.filteredUsers = []
            return
        }
        
        isLoading = true
        do {
            let querySnapshot = try await db.collection("users")
                .whereField("role", isEqualTo: role.rawValue)
                .whereField("name", isGreaterThanOrEqualTo: query)
                .whereField("name", isLessThanOrEqualTo: query + "\u{f8ff}")
                .getDocuments()
            
            var matchedUsers: [User] = []
            
            for document in querySnapshot.documents {
                let data = document.data()
                
                var brands: [Brand]?
                if let brandsData = data["brands"] as? [[String: Any]] {
                    brands = brandsData.compactMap { brandData in
                        guard let id = brandData["id"] as? String,
                              let name = brandData["name"] as? String else {
                            return nil
                        }
                        return Brand(id: id, name: name)
                    }
                }
                
                let user = User(
                    id: document.documentID,
                    email: data["email"] as? String ?? "",
                    name: data["name"] as? String ?? "",
                    role: UserRole(rawValue: data["role"] as? String ?? "") ?? .customer,
                    brands: brands,
                    profilePictureUrl: data["profilePictureUrl"] as? String
                )
                matchedUsers.append(user)
            }
            
            self.filteredUsers = matchedUsers
        } catch {
            self.error = error.localizedDescription
            self.filteredUsers = []
        }
        isLoading = false
    }
    
    func updateRelation(customers: [User], accountManager: User) async {
        isLoading = true
        do {
            let batch = db.batch()
            
            // Get current customer IDs for account manager
            let accountManagerDoc = try await db.collection("users").document(accountManager.id).getDocument()
            var existingCustomerIds = accountManagerDoc.data()?["customerIds"] as? [String] ?? []
            
            // Add new customer IDs without duplicates
            let newCustomerIds = customers.map { $0.id }
            existingCustomerIds.append(contentsOf: newCustomerIds)
            let uniqueCustomerIds = Array(Set(existingCustomerIds))
            
            // Update account manager with combined customer list
            let accountManagerRef = db.collection("users").document(accountManager.id)
            batch.updateData([
                "customerIds": uniqueCustomerIds
            ], forDocument: accountManagerRef)
            
            // Update each customer to have this account manager
            for customer in customers {
                let customerRef = db.collection("users").document(customer.id)
                batch.updateData([
                    "accountManagerId": accountManager.id
                ], forDocument: customerRef)
            }
            
            try await batch.commit()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
