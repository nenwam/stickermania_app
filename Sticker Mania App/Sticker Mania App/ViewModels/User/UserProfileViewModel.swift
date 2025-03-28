//
//  UserProfileViewModel.swift
//  Sticker Mania App
//
//  Created by Connor on 12/2/24.
//

import Foundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var profileImageUrl: String?
    @Published var associatedCustomers: [(id: String, email: String, name: String)] = []
    private let logger = LoggingService.shared
    
    func fetchProfileData() async -> (imageUrl: String?, name: String?) {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            logger.log("Failed to fetch profile data: No authenticated user", level: .warning)
            return (nil, nil)
        }
        
        logger.log("Fetching profile data for user: \(email)")
        let db = Firestore.firestore()
        do {
            let document = try await db.collection("users").document(email).getDocument()
            if let data = document.data() {
                let url = data["profilePictureUrl"] as? String
                let name = data["name"] as? String
                logger.log("Successfully fetched profile data for \(email)")
                return (url, name)
            }
            logger.log("No profile data found for user: \(email)", level: .warning)
            return (nil, nil)
        } catch {
            logger.log("Error fetching profile data: \(error.localizedDescription)", level: .error)
            return (nil, nil)
        }
    }
    
    func changeUsername(to newUsername: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            let errorMessage = "No user logged in"
            logger.log(errorMessage, level: .error)
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            return
        }
        
        logger.log("Changing username to: \(newUsername) for user: \(user.email ?? "unknown")")
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = newUsername
        
        changeRequest.commitChanges { [weak self] error in
            if let error = error {
                self?.logger.log("Failed to change username: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
            } else {
                self?.logger.log("Username changed successfully to: \(newUsername)")
                completion(.success(()))
            }
        }
    }
    
    func changePassword(to newPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            let errorMessage = "No user logged in"
            logger.log(errorMessage, level: .error)
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            return
        }
        
        logger.log("Changing password for user: \(user.email ?? "unknown")")
        user.updatePassword(to: newPassword) { [weak self] error in
            if let error = error {
                self?.logger.log("Failed to change password: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
            } else {
                self?.logger.log("Password changed successfully")
                completion(.success(()))
            }
        }
    }
    
    func uploadProfilePicture(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            let errorMessage = "No user logged in"
            logger.log(errorMessage, level: .error)
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            return
        }
        
        logger.log("Preparing to upload profile picture for user: \(user.email ?? user.uid)")
        let storageRef = Storage.storage().reference().child("profile_pictures/\(user.uid).jpg")
        
        // Resize image to max dimension of 1024 while maintaining aspect ratio
        let maxDimension: CGFloat = 1024
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        logger.log("Resizing image from \(image.size) to \(newSize)")
        UIGraphicsBeginImageContext(newSize)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let compressedImage = resizedImage,
              let imageData = compressedImage.jpegData(compressionQuality: 0.6) else {
            let errorMessage = "Image compression failed"
            logger.log(errorMessage, level: .error)
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            return
        }
        
        logger.log("Uploading profile picture: \(imageData.count) bytes")
        storageRef.putData(imageData, metadata: nil) { [weak self] metadata, error in
            if let error = error {
                self?.logger.log("Failed to upload profile picture: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
                return
            }
            
            self?.logger.log("Image uploaded, retrieving download URL")
            storageRef.downloadURL { [weak self] url, error in
                if let error = error {
                    self?.logger.log("Failed to get download URL: \(error.localizedDescription)", level: .error)
                    completion(.failure(error))
                } else if let url = url {
                    self?.logger.log("Got download URL: \(url.absoluteString)")
                    self?.updateProfilePictureUrl(url.absoluteString) { result in
                        switch result {
                        case .success:
                            self?.logger.log("Profile picture URL updated successfully in user document")
                            completion(.success(url.absoluteString))
                        case .failure(let error):
                            self?.logger.log("Failed to update profile picture URL: \(error.localizedDescription)", level: .error)
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }
    
    private func updateProfilePictureUrl(_ url: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            let errorMessage = "No user logged in or invalid email"
            logger.log(errorMessage, level: .error)
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            return
        }

        logger.log("Updating profile picture URL in Firestore for user: \(email)")
        
        let db = Firestore.firestore()
        db.collection("users").document(email).updateData([
            "profilePictureUrl": url
        ]) { [weak self] error in
            if let error = error {
                self?.logger.log("Error updating profile picture URL in Firestore: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
            } else {
                self?.logger.log("Profile picture URL updated successfully in Firestore")
                DispatchQueue.main.async {
                    self?.profileImageUrl = url
                }
                completion(.success(()))
            }
        }
    }
    
    func fetchAssociatedCustomers(customerIds: [String]) async {
        guard !customerIds.isEmpty else {
            logger.log("No customer IDs provided to fetch", level: .warning)
            return
        }
        
        logger.log("Fetching \(customerIds.count) associated customers for account manager")
        
        // Reset the current list
        self.associatedCustomers = []
        
        let db = Firestore.firestore()
        
        for customerId in customerIds {
            do {
                let document = try await db.collection("users").document(customerId).getDocument()
                
                guard document.exists, let data = document.data() else {
                    logger.log("Customer document not found: \(customerId)", level: .warning)
                    continue
                }
                
                let email = data["email"] as? String ?? ""
                let name = data["name"] as? String ?? "Unknown Customer"
                
                self.associatedCustomers.append((id: customerId, email: email, name: name))
                logger.log("Added customer to list: \(name) (\(email))")
            } catch {
                logger.log("Error fetching customer \(customerId): \(error.localizedDescription)", level: .error)
            }
        }
        
        logger.log("Finished loading \(self.associatedCustomers.count) associated customers")
    }
}
