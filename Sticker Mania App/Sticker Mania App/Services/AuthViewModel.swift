import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var isUserSignedIn: Bool = false
    @Published var userRole: UserRole?
    
    private let userService = UserService()
    private let db = Firestore.firestore()
    
    init() {
        listenToAuthState()
        print("AuthViewModel initialized")
    }

    private func listenToAuthState() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.isUserSignedIn = (user != nil)
            if let user = user, let email = user.email {
                print("Current user email: \(email)")
                self?.migrateUserIdIfNeeded(user: user)
                self?.fetchUserRole(email: email)
            } else {
                self?.userRole = nil
            }
        }
    }
    
    // Function to migrate user ID from email to UID if needed
    private func migrateUserIdIfNeeded(user: FirebaseAuth.User) {
        guard let email = user.email else { return }
        let uid = user.uid
        
        db.collection("users").document(email).getDocument { [weak self] snapshot, error in
            guard let snapshot = snapshot, snapshot.exists,
                  let data = snapshot.data() else { return }
            
            // Check if the id is using email or not matching UID
            if let id = data["id"] as? String, id != uid {
                print("Migrating user ID from \(id) to UID \(uid)")
                
                // Update the id field to use UID
                self?.db.collection("users").document(email).updateData([
                    "id": uid
                ]) { error in
                    if let error = error {
                        print("Error migrating user ID: \(error.localizedDescription)")
                    } else {
                        print("Successfully migrated user ID to UID for \(email)")
                    }
                }
            }
        }
    }
    
    private func fetchUserRole(email: String) {
        print("Fetching role for user email: \(email)")
        userService.fetchUserRole(email: email) { [weak self] result in
            switch result {
            case .success(let role):
                DispatchQueue.main.async {
                    self?.userRole = role
                }
            case .failure(let error):
                print("Error fetching user role: \(error.localizedDescription)")
                // Log out the user if role not found
                do {
                    try Auth.auth().signOut()
                    DispatchQueue.main.async {
                        self?.isUserSignedIn = false
                        self?.userRole = nil
                    }
                    print("User signed out due to missing role")
                } catch let signOutError {
                    print("Error signing out: \(signOutError.localizedDescription)")
                }
            }
        }
    }
}