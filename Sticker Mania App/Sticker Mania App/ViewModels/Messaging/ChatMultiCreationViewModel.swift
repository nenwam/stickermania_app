import FirebaseFirestore
import FirebaseAuth

class ChatMultiCreationViewModel: ObservableObject {
    @Published var customers: [String] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentUserCustomerIds: [String] = []
    @Published var currentUserRole: UserRole = .customer
    
    private let db = Firestore.firestore()
    private let chatCreationVM = ChatCreationViewModel()
    
    func loadCustomers() async {
        isLoading = true
        
        do {
            // Load all customers
            let snapshot = try await db.collection("users")
                .whereField("role", isEqualTo: "customer")
                .getDocuments()
            
            self.customers = snapshot.documents.compactMap { doc in
                doc.data()["email"] as? String
            }
            
            // Load current user's role and assigned customers if they are an account manager
            if let currentUserEmail = Auth.auth().currentUser?.email {
                let userDoc = try await db.collection("users").document(currentUserEmail).getDocument()
                if let userData = userDoc.data() {
                    if let role = userData["role"] as? String {
                        self.currentUserRole = UserRole(rawValue: role) ?? .customer
                    }
                    
                    if self.currentUserRole == .accountManager,
                       let assignedCustomers = userData["customerIds"] as? [String] {
                        self.currentUserCustomerIds = assignedCustomers
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func createProjectChats(selectedCustomers: Set<String>, 
                          printTeamParticipants: Set<String>,
                          designTeamParticipants: Set<String>) async throws {
        guard let currentUser = Auth.auth().currentUser?.email else {
            throw NSError(domain: "", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        for customer in selectedCustomers {
            print("Creating chats for customer: \(customer)")
            
            // Create account manager chat
            chatCreationVM.createChat(
                participants: [currentUser, customer],
                title: "Account Manager Chat",
                chatType: .customer
            )
            
            // Create print team chat
            var printParticipants = Set([currentUser, customer])
            printParticipants = printParticipants.union(printTeamParticipants)
            print("Print team participants: \(printParticipants)")
            
            chatCreationVM.createChat(
                participants: Array(printParticipants),
                title: "Print Team Chat",
                chatType: .customer
            )
            
            // Create design team chat
            var designParticipants = Set([currentUser, customer])
            designParticipants = designParticipants.union(designTeamParticipants)
            print("Design team participants: \(designParticipants)")
            
            chatCreationVM.createChat(
                participants: Array(designParticipants),
                title: "Design Team Chat", 
                chatType: .customer
            )
            
            print("Successfully created all chats for customer: \(customer)")
        }
    }
}
