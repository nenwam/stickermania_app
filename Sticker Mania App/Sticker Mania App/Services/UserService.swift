//
//  UserService.swift
//  Sticker Mania App
//
//  Created by Connor on 11/7/24.
//

import Foundation
import FirebaseFirestore

class UserService {
    private let db = Firestore.firestore()

    func fetchUserRole(userId: String, completion: @escaping (Result<UserRole, Error>) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(), let roleString = data["role"] as? String, let role = UserRole(rawValue: roleString) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Role not found"])))
                return
            }
            
            print("Successfully fetched user role: \(role)")
            completion(.success(role))
        }
    }
}