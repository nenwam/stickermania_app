import SwiftUI

class AuthenticationViewModel: ObservableObject {
    @Published var user: User?

    func signUp(email: String, password: String, name: String) {
        AuthenticationService.shared.signUp(email: email, password: password, name: name) { result in
            switch result {
            case .success(let user):
                self.user = user
            case .failure(let error):
                print("Sign up error: \(error.localizedDescription)")
            }
        }
    }

    func signIn(email: String, password: String) {
        AuthenticationService.shared.signIn(email: email, password: password) { result in
            switch result {
            case .success(let user):
                self.user = user
            case .failure(let error):
                print("Sign in error: \(error.localizedDescription)")
            }
        }
    }

    func signOut() {
        AuthenticationService.shared.signOut { result in
            switch result {
            case .success:
                self.user = nil
            case .failure(let error):
                print("Sign out error: \(error.localizedDescription)")
            }
        }
    }
}