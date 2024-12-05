//
//  ChatParticipantSelectViewModel.swift
//  Sticker Mania App
//
//  Created by Connor on 11/1/24.
//

import Foundation
import FirebaseFirestore

class ChatParticipantSelectViewModel: ObservableObject {
    @Published var filteredUsers: [User] = []
    private var userCache: [String: User] = [:]
    
    func searchUsers(matching query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                self.filteredUsers = []
            }
            return
        }
        
        let db = Firestore.firestore()
        let usersRef = db.collection("users")
        
        do {
            // Search for users where name or email contains the query
            let querySnapshot = try await usersRef
                .whereField("name", isGreaterThanOrEqualTo: query)
                .whereField("name", isLessThanOrEqualTo: query + "\u{f8ff}")
                .getDocuments()
            
            var matchedUsers: [User] = []
            
            for document in querySnapshot.documents {
                let data = document.data()
                if let email = data["email"] as? String,
                   let name = data["name"] as? String,
                   let roleString = data["role"] as? String {
                    let role: UserRole
                    switch roleString {
                    case "customer":
                        role = .customer
                    case "accountManager":
                        role = .accountManager
                    case "employee":
                        role = .employee
                    case "admin":
                        role = .admin
                    case "suspended":
                        role = .suspended
                    default:
                        continue
                    }
                    
                    // Handle brands array
                    var brands: [Brand] = []
                    if let brandsData = data["brands"] as? [[String: Any]] {
                        brands = brandsData.compactMap { brandData in
                            guard let id = brandData["id"] as? String,
                                  let name = brandData["name"] as? String else {
                                return nil
                            }
                            return Brand(id: id, name: name)
                        }
                    }
                    
                    // Get profile picture URL if it exists
                    let profilePictureUrl = data["profilePictureUrl"] as? String
                    
                    let user = User(id: email,
                                  email: email,
                                  name: name,
                                  role: role,
                                  brands: brands,
                                  profilePictureUrl: profilePictureUrl)
                    matchedUsers.append(user)
                    self.userCache[user.email] = user
                    
                    // Print participant details
                    print("Found participant - Name: \(name), Email: \(email), Role: \(roleString)")
                }
            }
            let usersToDisplay = matchedUsers
            await MainActor.run {
                self.filteredUsers = usersToDisplay
                print("Total participants found: \(usersToDisplay.count)")
            }
        } catch {
            print("Error searching users: \(error.localizedDescription)")
            await MainActor.run {
                self.filteredUsers = []
            }
        }
    }
    
    func getUser(by email: String) -> User? {
        return userCache[email]
    }
}