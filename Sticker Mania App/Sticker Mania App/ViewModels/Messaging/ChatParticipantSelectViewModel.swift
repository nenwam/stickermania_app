//
//  ChatParticipantSelectViewModel.swift
//  Sticker Mania App
//
//  Created by Connor on 11/1/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
class ChatParticipantSelectViewModel: ObservableObject {
    @Published var filteredUsers: [User] = []
    private var userCache: [String: User] = [:]
    private var searchTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.5 // 500ms debounce
    private let logger = LoggingService.shared
    
    func searchUsers(matching query: String) async {
        // Cancel any previous search task
        searchTask?.cancel()
        
        // Create a new search task with debounce
        searchTask = Task {
            // Debounce by waiting a short interval
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            
            // Check if task was cancelled during the sleep
            if Task.isCancelled { return }
            
            guard !query.isEmpty else {
                await MainActor.run {
                    self.filteredUsers = []
                }
                return
            }
            
            logger.log("Searching for users matching: '\(query)'")
            let db = Firestore.firestore()
            let usersRef = db.collection("users")
            
            do {
                // *** SOLUTION: Get all users and filter client-side ***
                // This avoids the compound query that's not working on iOS 18
                logger.log("Using client-side filtering approach")
                let allUsersSnapshot = try await usersRef.getDocuments()
                logger.log("Retrieved \(allUsersSnapshot.documents.count) total users")
                
                var matchedUsers: [User] = []
                let lowercaseQuery = query.lowercased()
                
                for document in allUsersSnapshot.documents {
                    let data = document.data()
                    if let email = data["email"] as? String,
                       let name = data["name"] as? String,
                       let roleString = data["role"] as? String,
                       name.lowercased().contains(lowercaseQuery) {
                        
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
                            logger.log("Unknown role type: \(roleString)", level: .warning)
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
                                      profilePictureUrl: profilePictureUrl,
                                      userRelationIds: nil)
                        matchedUsers.append(user)
                        
                        logger.log("Found matching user: \(name) (\(email))")
                    }
                }
                
                await MainActor.run {
                    // Update the cache on the main thread to prevent race conditions
                    for user in matchedUsers {
                        self.userCache[user.email] = user
                    }
                    self.filteredUsers = matchedUsers
                    logger.log("Updated UI with \(matchedUsers.count) matching participants")
                }
            } catch {
                logger.log("Search error: \(error.localizedDescription)", level: .error)
                await MainActor.run {
                    self.filteredUsers = []
                }
            }
        }
    }
    
    func getUser(by email: String) -> User? {
        // Check if we have a valid email before accessing the dictionary
        guard !email.isEmpty else { 
            logger.log("Attempted to get user with empty email", level: .warning)
            return nil 
        }
        
        // Safely access the userCache dictionary
        if let user = userCache[email] {
            logger.log("Retrieved cached user: \(user.name)")
            return user
        }
        
        logger.log("User not found in cache for email: \(email)", level: .info)
        return nil
    }
}
