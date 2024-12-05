import FirebaseFirestore
import FirebaseAuth

class ChatMultiCreationViewModel: ObservableObject {
    @Published var customers: [String] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private let chatCreationVM = ChatCreationViewModel()
    
    func loadCustomers() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("users")
                .whereField("role", isEqualTo: "customer")
                .getDocuments()
            
            self.customers = snapshot.documents.compactMap { doc in
                doc.data()["email"] as? String
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
