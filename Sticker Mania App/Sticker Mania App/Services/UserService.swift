//
//  UserService.swift
//  Sticker Mania App
//
//  Created by Connor on 11/7/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class UserService {
    private let db = Firestore.firestore()
    private let logger = LoggingService.shared
    
    func fetchUserRole(email: String, completion: @escaping (Result<UserRole, Error>) -> Void) {
        logger.log("Fetching user role for email: \(email)")
        // Check if we have a current user with this email
        if let currentUser = Auth.auth().currentUser, currentUser.email == email {
            // If so, try getting by UID first
            logger.log("Using current user UID: \(currentUser.uid)")
            fetchUserRoleByUid(uid: currentUser.uid) { result in
                switch result {
                case .success(let role):
                    self.logger.log("Successfully retrieved role by UID: \(role.rawValue)")
                    completion(.success(role))
                case .failure(let error):
                    self.logger.log("Failed to retrieve role by UID, falling back to email: \(error.localizedDescription)", level: .warning)
                    // If UID lookup fails, fall back to email
                    self.fetchUserRoleByEmail(email: email, completion: completion)
                }
            }
        } else {
            // Otherwise just use email
            logger.log("No matching current user, using email lookup directly")
            fetchUserRoleByEmail(email: email, completion: completion)
        }
    }
    
    private func fetchUserRoleByUid(uid: String, completion: @escaping (Result<UserRole, Error>) -> Void) {
        logger.log("Fetching user role by UID: \(uid)")
        db.collection("users").whereField("id", isEqualTo: uid).getDocuments { snapshot, error in
            if let error = error {
                self.logger.log("Firestore error while fetching by UID: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents, 
                  !documents.isEmpty,
                  let document = documents.first else {
                let errorMessage = "User document not found by UID"
                self.logger.log(errorMessage, level: .error)
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            let data = document.data()
            guard let roleString = data["role"] as? String,
                  let role = UserRole(rawValue: roleString) else {
                let errorMessage = "Role not found by UID"
                self.logger.log(errorMessage, level: .error)
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            self.logger.log("Successfully fetched user role by UID: \(role.rawValue)")
            completion(.success(role))
        }
    }
    
    private func fetchUserRoleByEmail(email: String, completion: @escaping (Result<UserRole, Error>) -> Void) {
        logger.log("Fetching user role by email: \(email)")
        db.collection("users").document(email).getDocument { snapshot, error in
            if let error = error {
                self.logger.log("Firestore error while fetching by email: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(), let roleString = data["role"] as? String, let role = UserRole(rawValue: roleString) else {
                let errorMessage = "Role not found by email"
                self.logger.log(errorMessage, level: .error)
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            self.logger.log("Successfully fetched user role by email: \(role.rawValue)")
            completion(.success(role))
        }
    }

    func getUserRole(email: String) async throws -> UserRole {
        logger.log("Async: Fetching user role for email: \(email)")
        
        // Check if we have a current user with this email
        if let currentUser = Auth.auth().currentUser, currentUser.email == email {
            // If so, try getting by UID first
            logger.log("Async: Using current user UID: \(currentUser.uid)")
            do {
                let role = try await getUserRoleByUid(uid: currentUser.uid)
                logger.log("Async: Successfully retrieved role by UID: \(role.rawValue)")
                return role
            } catch {
                logger.log("Async: Failed to retrieve role by UID, falling back to email: \(error.localizedDescription)", level: .warning)
                // If UID lookup fails, fall back to email
                return try await getUserRoleByEmail(email: email)
            }
        } else {
            // Otherwise just use email
            logger.log("Async: No matching current user, using email lookup directly")
            return try await getUserRoleByEmail(email: email)
        }
    }

    private func getUserRoleByUid(uid: String) async throws -> UserRole {
        logger.log("Async: Fetching user role by UID: \(uid)")
        
        let snapshot = try await db.collection("users").whereField("id", isEqualTo: uid).getDocuments()
        
        let documents = snapshot.documents
        guard !documents.isEmpty,
              let document = documents.first else {
            let errorMessage = "User document not found by UID"
            logger.log("Async: \(errorMessage)", level: .error)
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        let data = document.data()
        guard let roleString = data["role"] as? String,
              let role = UserRole(rawValue: roleString) else {
            let errorMessage = "Role not found by UID"
            logger.log("Async: \(errorMessage)", level: .error)
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        logger.log("Async: Successfully fetched user role by UID: \(role.rawValue)")
        return role
    }

    private func getUserRoleByEmail(email: String) async throws -> UserRole {
        logger.log("Async: Fetching user role by email: \(email)")
        
        let snapshot = try await db.collection("users").document(email).getDocument()
        
        guard let data = snapshot.data(),
              let roleString = data["role"] as? String,
              let role = UserRole(rawValue: roleString) else {
            let errorMessage = "Role not found by email"
            logger.log("Async: \(errorMessage)", level: .error)
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        logger.log("Async: Successfully fetched user role by email: \(role.rawValue)")
        return role
    }
}