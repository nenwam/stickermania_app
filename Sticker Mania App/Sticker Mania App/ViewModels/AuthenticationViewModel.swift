import SwiftUI
import FirebaseAuth
import FirebaseCrashlytics
import Foundation
// LoggingService is a local class, not a module

class AuthenticationViewModel: ObservableObject {
    @Published var user: User?
    private let logger = LoggingService.shared

    func signUp(email: String, password: String, name: String) {
        AuthenticationService.shared.signUp(email: email, password: password, name: name) { result in
            switch result {
            case .success(let user):
                self.user = user
                
                // Set user identification in LoggingService
                self.logger.setUserContext(userId: user.id, email: user.email, name: user.name, role: user.role.rawValue)
                self.logger.log("User signed up successfully", level: .info)
                
            case .failure(let error):
                print("Sign up error: \(error.localizedDescription)")
                
                // Log error to LoggingService
                self.logger.log("Sign up failed: \(error.localizedDescription)", level: .error)
            }
        }
    }

    func signIn(email: String, password: String) {
        AuthenticationService.shared.signIn(email: email, password: password) { result in
            switch result {
            case .success(let user):
                self.user = user
                
                // Set user identification in LoggingService
                self.logger.setUserContext(userId: user.id, email: user.email, name: user.name, role: user.role.rawValue)
                
                // Log device info
                let deviceModel = UIDevice.current.model
                let osVersion = UIDevice.current.systemVersion
                self.logger.log("User signed in successfully", level: .info)
                self.logger.logUserAction("user_sign_in", parameters: [
                    "device_model": deviceModel,
                    "ios_version": osVersion
                ])
                
            case .failure(let error):
                print("Sign in error: \(error.localizedDescription)")
                
                // Log error to LoggingService with context
                self.logger.log("Sign in failed for email \(email): \(error.localizedDescription)", level: .error)
            }
        }
    }

    func signOut() {
        AuthenticationService.shared.signOut { result in
            switch result {
            case .success:
                self.user = nil
                
                // Clear user identification in LoggingService
                self.logger.clearUserContext()
                self.logger.log("User signed out successfully", level: .info)
                
            case .failure(let error):
                print("Sign out error: \(error.localizedDescription)")
                
                // Log error to LoggingService
                self.logger.log("Sign out failed: \(error.localizedDescription)", level: .error)
            }
        }
    }
}