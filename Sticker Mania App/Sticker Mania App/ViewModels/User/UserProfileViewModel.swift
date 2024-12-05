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
    
    func fetchProfileData() async -> (imageUrl: String?, name: String?) {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            return (nil, nil)
        }
        
        let db = Firestore.firestore()
        do {
            let document = try await db.collection("users").document(email).getDocument()
            if let data = document.data() {
                let url = data["profilePictureUrl"] as? String
                let name = data["name"] as? String
                return (url, name)
            }
            return (nil, nil)
        } catch {
            print("Error fetching profile data: \(error.localizedDescription)")
            return (nil, nil)
        }
    }
    
    func changeUsername(to newUsername: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = newUsername
        
        changeRequest.commitChanges { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func changePassword(to newPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        
        user.updatePassword(to: newPassword) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func uploadProfilePicture(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        
        let storageRef = Storage.storage().reference().child("profile_pictures/\(user.uid).jpg")
        
        // Resize image to max dimension of 1024 while maintaining aspect ratio
        let maxDimension: CGFloat = 1024
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        UIGraphicsBeginImageContext(newSize)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let compressedImage = resizedImage,
              let imageData = compressedImage.jpegData(compressionQuality: 0.6) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Image compression failed"])))
            return
        }
        
        storageRef.putData(imageData, metadata: nil) { [weak self] metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let url = url {
                    self?.updateProfilePictureUrl(url.absoluteString) { result in
                        switch result {
                        case .success:
                            completion(.success(url.absoluteString))
                        case .failure(let error):
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
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in or invalid email"])))
            return
        }

        print("User email: \(email)")
        
        let db = Firestore.firestore()
        db.collection("users").document(email).updateData([
            "profilePictureUrl": url
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                DispatchQueue.main.async {
                    self.profileImageUrl = url
                }
                completion(.success(()))
            }
        }
    }
}
