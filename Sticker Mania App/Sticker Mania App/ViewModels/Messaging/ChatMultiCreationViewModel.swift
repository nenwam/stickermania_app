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
    private let logger = LoggingService.shared
    
    func loadCustomers() async {
        logger.log("Loading customers for chat creation")
        isLoading = true
        
        do {
            // Load all customers
            logger.log("Querying all users with customer role")
            let snapshot = try await db.collection("users")
                .whereField("role", isEqualTo: "customer")
                .getDocuments()
            
            self.customers = snapshot.documents.compactMap { doc in
                doc.data()["email"] as? String
            }
            logger.log("Found \(self.customers.count) customers")
            
            // Load current user's role and assigned customers if they are an account manager
            if let currentUserEmail = Auth.auth().currentUser?.email {
                logger.log("Loading role and assigned customers for current user: \(currentUserEmail)")
                let userDoc = try await db.collection("users").document(currentUserEmail).getDocument()
                if let userData = userDoc.data() {
                    if let role = userData["role"] as? String {
                        self.currentUserRole = UserRole(rawValue: role) ?? .customer
                        logger.log("Current user role: \(self.currentUserRole.rawValue)")
                    }
                    
                    if self.currentUserRole == .accountManager,
                       let assignedCustomers = userData["customerIds"] as? [String] {
                        self.currentUserCustomerIds = assignedCustomers
                        logger.log("Account manager has \(assignedCustomers.count) assigned customers")
                    }
                }
            } else {
                logger.log("No current user email found", level: .warning)
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        } catch {
            logger.log("Error loading customers: \(error.localizedDescription)", level: .error)
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func createProjectChats(selectedCustomers: Set<String>, 
                          printTeamParticipants: Set<String>,
                          designTeamParticipants: Set<String>,
                          fileSetupParticipants: Set<String>) async throws {
        guard let currentUser = Auth.auth().currentUser?.email else {
            let errorMessage = "No user logged in"
            logger.log(errorMessage, level: .error)
            throw NSError(domain: "", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        logger.log("Creating project chats for \(selectedCustomers.count) customers")
        
        for customer in selectedCustomers {
            logger.log("Creating chat set for customer: \(customer)")
            
            // Create account manager chat
            logger.log("Creating account manager chat with \(customer)")
            chatCreationVM.createChat(
                participants: [currentUser, customer],
                title: "Account Manager Chat",
                chatType: .customer
            )
            
            // Create print team chat
            var printParticipants = Set([currentUser, customer])
            printParticipants = printParticipants.union(printTeamParticipants)
            logger.log("Creating print team chat with \(printParticipants.count) participants")
            
            chatCreationVM.createChat(
                participants: Array(printParticipants),
                title: "Print Team Chat",
                chatType: .customer
            )
            
            // Create design team chat
            var designParticipants = Set([currentUser, customer])
            designParticipants = designParticipants.union(designTeamParticipants)
            logger.log("Creating design team chat with \(designParticipants.count) participants")
            
            chatCreationVM.createChat(
                participants: Array(designParticipants),
                title: "Design Team Chat", 
                chatType: .customer
            )
            
            // Create file setup chat
            var fileSetupTeam = Set([currentUser, customer])
            fileSetupTeam = fileSetupTeam.union(fileSetupParticipants)
            logger.log("Creating file setup chat with \(fileSetupTeam.count) participants")
            
            chatCreationVM.createChat(
                participants: Array(fileSetupTeam),
                title: "File Setup Chat", 
                chatType: .customer
            )
            
            logger.log("Successfully created all chats for customer: \(customer)")
        }
    }
}
