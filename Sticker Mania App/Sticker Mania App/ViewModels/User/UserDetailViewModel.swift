//
//  UserDetailViewModel.swift
//  Sticker Mania App
//
//  Created by Connor on 11/26/24.
//

import Foundation
import FirebaseFirestore

class UserDetailViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    
    func fetchUser(userId: String) {
        isLoading = true
        error = nil
        
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { [weak self] document, err in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let err = err {
                    self?.error = err.localizedDescription
                    return
                }
                
                guard let document = document, document.exists,
                      let data = document.data() else {
                    self?.error = "User not found"
                    return
                }
                
                // Parse brands data
                let brandsData = data["brands"] as? [[String: Any]] ?? []
                let brands = brandsData.compactMap { brandData -> Brand? in
                    guard let id = brandData["id"] as? String,
                          let name = brandData["name"] as? String else {
                        return nil
                    }
                    return Brand(id: id, name: name)
                }
                
                // Create user object
                let user = User(
                    id: document.documentID,
                    email: data["email"] as? String ?? "",
                    name: data["name"] as? String ?? "",                    
                    role: UserRole(rawValue: data["role"] as? String ?? "") ?? .customer,
                    brands: brands
                )
                
                self?.user = user
            }
        }
    }
    
    func updateBrands(brands: [Brand]) {
        guard let userId = user?.id else { return }
        
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
                    self?.error = err.localizedDescription
                    return
                }
                
                // Update local user object with new brands
                self?.user?.brands = brands
            }
        }
    }
}
