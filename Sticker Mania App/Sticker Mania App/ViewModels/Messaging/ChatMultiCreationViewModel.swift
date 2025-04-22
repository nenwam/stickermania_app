import FirebaseFirestore
import FirebaseAuth

// Assume User struct exists and is Decodable & Identifiable
// struct User: Identifiable, Decodable, Hashable {
//     var id: String // Or @DocumentID var id: String?
//     var email: String
//     var name: String
//     var role: String
//     // Make sure it's Hashable if needed for Sets based on the object itself
// }

class ChatMultiCreationViewModel: ObservableObject {
    @Published var customers: [User] = [] // Changed from [String]
    @Published var nonCustomerUsers: [User] = [] // Changed from [String]
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentUserCustomerIds: [String] = [] // Keep as emails
    @Published var currentUserRole: UserRole = .customer
    
    private let db = Firestore.firestore()
    private let chatCreationVM = ChatCreationViewModel() // Assuming this expects email strings
    private let logger = LoggingService.shared
    
    func loadCustomers() async {
        logger.log("Loading customers and non-customer users for chat creation")
        DispatchQueue.main.async { // Set loading on main thread
             self.isLoading = true
             self.error = nil // Reset error on new load
         }
        
        do {
            // Load all users once
            logger.log("Querying all users")
            let allUsersSnapshot = try await db.collection("users").getDocuments()
            let allUsers = allUsersSnapshot.documents.compactMap { doc -> User? in
                try? doc.data(as: User.self) // Decode User objects
            }
            logger.log("Successfully decoded \(allUsers.count) total users")

            // Filter users into customers and non-customers
            var fetchedCustomers: [User] = []
            var fetchedNonCustomers: [User] = []
            
            for user in allUsers {
                if "\(user.role)".lowercased() == "customer" {
                    fetchedCustomers.append(user)
                } else {
                    fetchedNonCustomers.append(user)
                }
            }
            
            logger.log("Found \(fetchedCustomers.count) customers and \(fetchedNonCustomers.count) non-customer users")

            // Load current user's role and assigned customers
             if let currentUserEmail = Auth.auth().currentUser?.email {
                 logger.log("Loading role and assigned customers for current user: \(currentUserEmail)")
                 // Find current user data from the already fetched list if possible
                 if let currentUserData = allUsers.first(where: { $0.email == currentUserEmail }) {
                      DispatchQueue.main.async {
                          self.currentUserRole = UserRole(rawValue: currentUserData.role.rawValue) ?? .customer
                          self.logger.log("Current user role: \(self.currentUserRole.rawValue)")
                          // Assuming customerIds field exists on User model if needed
                          // if self.currentUserRole == .accountManager, let assigned = currentUserData.customerIds {
                          //     self.currentUserCustomerIds = assigned
                          // }
                      }
                      // If customerIds are stored differently, fetch the document specifically
                      let userDoc = try await db.collection("users").document(currentUserEmail).getDocument()
                       if let userData = userDoc.data(),
                          self.currentUserRole == .accountManager, // Check role again just in case
                          let assignedCustomers = userData["customerIds"] as? [String] {
                           DispatchQueue.main.async {
                               self.currentUserCustomerIds = assignedCustomers
                               self.logger.log("Account manager has \(assignedCustomers.count) assigned customers")
                           }
                       }
                 } else {
                      logger.log("Current user \(currentUserEmail) not found in fetched users list.", level: .warning)
                 }
             } else {
                 logger.log("No current user email found", level: .warning)
             }
            
            // Update published properties on the main thread
            DispatchQueue.main.async {
                self.customers = fetchedCustomers
                self.nonCustomerUsers = fetchedNonCustomers
                self.isLoading = false
            }
        } catch {
            logger.log("Error loading users: \(error.localizedDescription)", level: .error)
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    // Keep signature accepting emails (Strings) as ChatCreationViewModel likely expects them
    func createProjectChats(selectedCustomers: Set<String>, 
                          printTeamParticipants: Set<String>,
                          designTeamParticipants: Set<String>,
                          fileSetupParticipants: Set<String>) async throws {
        guard let currentUserEmail = Auth.auth().currentUser?.email else { // Use email here
            let errorMessage = "No user logged in"
            logger.log(errorMessage, level: .error)
            throw NSError(domain: "", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        logger.log("Creating project chats for \(selectedCustomers.count) customers (emails: \(selectedCustomers))")
        
        for customerEmail in selectedCustomers { // Iterate over emails
            logger.log("Creating chat set for customer: \(customerEmail)")
            
            // Create account manager chat (pass emails)
            logger.log("Creating account manager chat with \(customerEmail)")
            chatCreationVM.createChat(
                participants: [currentUserEmail, customerEmail], // Use emails
                title: "Account Manager Chat",
                chatType: .customer
            )
            
            // Create print team chat
            var printParticipantsEmails = Set([currentUserEmail, customerEmail]) // Start with emails
            printParticipantsEmails = printParticipantsEmails.union(printTeamParticipants) // Union with emails
            logger.log("Creating print team chat with \(printParticipantsEmails.count) participants")
            
            chatCreationVM.createChat(
                participants: Array(printParticipantsEmails),
                title: "Print Team Chat",
                chatType: .customer
            )
            
            // Create design team chat
            var designParticipantsEmails = Set([currentUserEmail, customerEmail]) // Start with emails
            designParticipantsEmails = designParticipantsEmails.union(designTeamParticipants) // Union with emails
            logger.log("Creating design team chat with \(designParticipantsEmails.count) participants")
            
            chatCreationVM.createChat(
                participants: Array(designParticipantsEmails),
                title: "Design Team Chat", 
                chatType: .customer
            )
            
            // Create file setup chat
            var fileSetupTeamEmails = Set([currentUserEmail, customerEmail]) // Start with emails
            fileSetupTeamEmails = fileSetupTeamEmails.union(fileSetupParticipants) // Union with emails
            logger.log("Creating file setup chat with \(fileSetupTeamEmails.count) participants")
            
            chatCreationVM.createChat(
                participants: Array(fileSetupTeamEmails),
                title: "File Setup Chat", 
                chatType: .customer
            )
            
            logger.log("Successfully created all chats for customer: \(customerEmail)")
        }
    }
}
