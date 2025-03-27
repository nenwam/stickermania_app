import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ChatUserCreationTest: View {
    @Environment(\.dismiss) private var dismiss
    @State private var userId: String = ""
    @State private var email: String = ""
    @State private var name: String = ""
    @State private var selectedRole: UserRole = .customer
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Details")) {
                    TextField("Username", text: $userId)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    
                    Picker("Role", selection: $selectedRole) {
                        Text("Customer").tag(UserRole.customer)
                        Text("Employee").tag(UserRole.employee)
                        Text("Account Manager").tag(UserRole.accountManager)
                        Text("Admin").tag(UserRole.admin)
                    }
                }
            }
            .navigationTitle("Create Test User")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Create") {
                    createUser()
                    dismiss()
                }
                .disabled(userId.isEmpty || email.isEmpty || name.isEmpty)
            )
        }
    }
    
    private func createUser() {
        let db = Firestore.firestore()
        
        // Create Firebase Auth user first to get UID
        Auth.auth().createUser(withEmail: email, password: "password123") { authResult, error in
            if let error = error {
                print("Error creating auth user: \(error.localizedDescription)")
                return
            }
            
            guard let uid = authResult?.user.uid else {
                print("Failed to get user UID")
                return
            }
            
            let userData: [String: Any] = [
                "id": uid, // Use UID instead of userId
                "email": self.email,
                "name": self.name,
                "role": self.selectedRole.rawValue
            ]
            
            db.collection("users").document(self.email).setData(userData) { error in
                if let error = error {
                    print("Error creating user: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct ChatUserCreationTest_Previews: PreviewProvider {
    static var previews: some View {
        ChatUserCreationTest()
    }
}
