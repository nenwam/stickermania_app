// Services/AuthenticationService.swift
import FirebaseAuth
import FirebaseFirestore

class AuthenticationService {
    static let shared = AuthenticationService()
    private let db = Firestore.firestore()

    func signUp(email: String, password: String, name: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let authResult = authResult else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication result is missing"])))
                return
            }
            
            let userId = authResult.user.uid
            let user = User(id: userId, email: authResult.user.email ?? "", name: name, role: .customer, brands: [], userRelationIds: nil)
            
            let userData: [String: Any] = [
                "email": email,
                "id": userId,
                "name": name,
                "role": "customer" // Use string literal instead of enum raw value
            ]
            
            // Ensure we're on the main thread when accessing Firestore
            DispatchQueue.main.async {
                self.db.collection("users").document(userData["email"] as! String).setData(userData) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(user))
                    }
                }
            }
        }
    }

    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(error))
            } else if let authResult = authResult {
                let user = User(id: authResult.user.uid, email: authResult.user.email ?? "", name: "", role: .customer, brands: [], userRelationIds: nil) // Fetch role from database
                completion(.success(user))
            }
        }
    }

    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try Auth.auth().signOut()
            completion(.success(()))
        } catch let signOutError as NSError {
            completion(.failure(signOutError))
        }
    }
}