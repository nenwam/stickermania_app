import Foundation
import SwiftUI
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var isUserSignedIn: Bool = false
    @Published var userRole: UserRole?
    
    private let userService = UserService()
    
    init() {
        listenToAuthState()
        print("AuthViewModel initialized")
    }

    private func listenToAuthState() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.isUserSignedIn = (user != nil)
            if let user = user, let email = user.email {
                print("Current user email: \(email)")
                self?.fetchUserRole(email: email)
            } else {
                self?.userRole = nil
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
            }
        }
    }
}