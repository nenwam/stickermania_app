import Foundation
import SwiftUI
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var isUserSignedIn: Bool = false
    @Published var userRole: UserRole?
    
    private let userService = UserService()
    
    init() {
        listenToAuthState()
    }

    private func listenToAuthState() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.isUserSignedIn = (user != nil)
            if let user = user {
                let userId = user.email?.components(separatedBy: "@").first ?? ""
                print("Current user ID: \(userId)")
                self?.fetchUserRole(userId: userId)
            } else {
                self?.userRole = nil
            }
        }
    }
    
    private func fetchUserRole(userId: String) {
        print("Fetching role for user ID: \(userId)")
        userService.fetchUserRole(userId: userId) { [weak self] result in
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