import FirebaseFirestore
import FirebaseAuth
import UIKit

class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var participantNames: [String: String] = [:] // Cache for participant names
    @Published var canDeleteChats = false // Flag to indicate if user can delete chats
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let logger = LoggingService.shared
    
    init() {
        checkUserPermissions() // Check if user can delete chats
    }
    
    // Check if the current user is admin or account manager
    private func checkUserPermissions() {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            logger.log("No current user found when checking permissions", level: .error)
            return
        }
        
        logger.log("Checking delete permissions for user: \(currentUserEmail)")
        
        db.collection("users").document(currentUserEmail).getDocument { [weak self] document, error in
            guard let self = self, let document = document, document.exists else {
                self?.logger.log("User document not found when checking permissions", level: .error)
                return
            }
            
            if let roleString = document.data()?["role"] as? String {
                // Check if user is admin or account manager
                if roleString == "admin" || roleString == "accountManager" {
                    DispatchQueue.main.async {
                        self.canDeleteChats = true
                        self.logger.log("User has delete chat permissions: \(roleString)")
                    }
                } else {
                    self.logger.log("User does not have delete chat permissions: \(roleString)")
                }
            }
        }
    }
    
    // Function to delete a chat
    func deleteChat(chatId: String) {
        logger.log("Attempting to delete chat with ID: \(chatId)")
        isLoading = true
        
        db.collection("chats").document(chatId).delete { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.logger.log("Error deleting chat: \(error.localizedDescription)", level: .error)
                self.error = error
                return
            }
            
            // Remove the chat from the local array if it exists
            if let index = self.chats.firstIndex(where: { $0.id == chatId }) {
                DispatchQueue.main.async {
                    self.chats.remove(at: index)
                }
            }
            
            self.logger.log("Successfully deleted chat with ID: \(chatId)")
        }
    }
    
    func fetchChats() {
        isLoading = true
        logger.log("Fetching chats for current user")
        
        // Query chats where current user is a participant
        guard let currentUserEmail = Auth.auth().currentUser?.email else { 
            logger.log("No user email found for fetching chats", level: .error)
            return 
        }
        
        let query = db.collection("chats")
            .whereField("participants", arrayContains: currentUserEmail)
            .order(by: "lastMessageTimestamp", descending: true)
        
        logger.log("Starting chat listener for user: \(currentUserEmail)")
        listener = query.addSnapshotListener { [weak self] (snapshot: QuerySnapshot?, error: Error?) in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.error = error
                self.logger.log("Error fetching chats: \(error.localizedDescription)", level: .error)
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.logger.log("No chat documents found", level: .info)
                return
            }
            
            self.logger.log("Retrieved \(documents.count) chats")
            self.chats = documents.compactMap { document -> Chat? in
                let data = document.data()
                
                guard let participants = data["participants"] as? [String],
                      let lastMessageData = data["lastMessage"] as? [String: Any],
                      let messageId = lastMessageData["id"] as? String,
                      let senderId = lastMessageData["senderId"] as? String,
                      let text = lastMessageData["text"] as? String,
                      let timestamp = (lastMessageData["timestamp"] as? Timestamp)?.dateValue(),
                      let typeString = data["type"] as? String,
                      let type = ChatType(rawValue: typeString),
                      let unreadStatus = data["unreadStatus"] as? [String: Bool] else {
                    self.logger.log("Failed to parse chat document: \(document.documentID)", level: .warning)
                    return nil
                }
                
                let lastMessage = ChatMessage(
                    id: messageId,
                    senderId: senderId,
                    text: text,
                    mediaUrl: nil,
                    thumbnailUrl: nil,
                    mediaType: nil,
                    timestamp: timestamp
                )
                
                let title = data["title"] as? String
                
                return Chat(
                    id: document.documentID,
                    participants: participants,
                    lastMessage: lastMessage,
                    type: type,
                    unreadStatus: unreadStatus,
                    title: title
                )
            }
            
            // Update app badge count after loading chats
            self.updateAppBadge()
        }
    }
    
    // Fetch a single chat by ID and verify the current user has access to it
    func fetchSingleChat(chatId: String) async throws {
        logger.log("Directly fetching single chat with ID: \(chatId)")
        
        guard let currentUserEmail = Auth.auth().currentUser?.email else { 
            logger.log("No user email found for fetching chat", level: .error)
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        do {
            let document = try await db.collection("chats").document(chatId).getDocument()
            
            guard document.exists else {
                logger.log("Chat \(chatId) does not exist", level: .error)
                throw NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Chat not found"])
            }
            
            guard let data = document.data() else {
                logger.log("Chat \(chatId) exists but has no data", level: .error)
                throw NSError(domain: "Firestore", code: 500, userInfo: [NSLocalizedDescriptionKey: "Chat data missing"])
            }
            
            // Verify user has access to this chat
            guard let participants = data["participants"] as? [String], 
                  participants.contains(currentUserEmail) else {
                logger.log("User \(currentUserEmail) does not have access to chat \(chatId)", level: .error)
                throw NSError(domain: "Auth", code: 403, userInfo: [NSLocalizedDescriptionKey: "Access denied"])
            }
            
            // Extract the required fields
            guard let lastMessageData = data["lastMessage"] as? [String: Any],
                  let messageId = lastMessageData["id"] as? String,
                  let senderId = lastMessageData["senderId"] as? String,
                  let text = lastMessageData["text"] as? String,
                  let timestamp = (lastMessageData["timestamp"] as? Timestamp)?.dateValue(),
                  let typeString = data["type"] as? String,
                  let type = ChatType(rawValue: typeString),
                  let unreadStatus = data["unreadStatus"] as? [String: Bool] else {
                logger.log("Failed to parse chat document: \(document.documentID)", level: .warning)
                throw NSError(domain: "Parsing", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid chat data format"])
            }
            
            let lastMessage = ChatMessage(
                id: messageId,
                senderId: senderId,
                text: text,
                mediaUrl: nil,
                thumbnailUrl: nil,
                mediaType: nil,
                timestamp: timestamp
            )
            
            let title = data["title"] as? String
            
            let chat = Chat(
                id: document.documentID,
                participants: participants,
                lastMessage: lastMessage,
                type: type,
                unreadStatus: unreadStatus,
                title: title
            )
            
            // Add this chat to our list if it's not already there
            DispatchQueue.main.async {
                if !self.chats.contains(where: { $0.id == chatId }) {
                    self.chats.append(chat)
                    self.logger.log("Added chat \(chatId) to the chat list")
                }
            }
            
            logger.log("Successfully fetched and processed chat: \(chatId)")
            return
            
        } catch {
            logger.log("Error fetching chat \(chatId): \(error.localizedDescription)", level: .error)
            throw error
        }
    }
    
    func getParticipantNames(for participantIds: [String], completion: @escaping ([String]) -> Void) {
        logger.log("Getting names for \(participantIds.count) participants")
        var names: [String] = []
        let dispatchGroup = DispatchGroup()
        
        for email in participantIds {
            if let cachedName = participantNames[email] {
                names.append(cachedName)
                logger.log("Using cached name for: \(email)")
            } else {
                dispatchGroup.enter()
                logger.log("Fetching name for participant: \(email)")
                db.collection("users").whereField("email", isEqualTo: email).getDocuments { [weak self] snapshot, error in
                    defer { dispatchGroup.leave() }
                    
                    if let error = error {
                        self?.logger.log("Error fetching participant data: \(error.localizedDescription)", level: .error)
                        return
                    }
                    
                    if let document = snapshot?.documents.first,
                       let data = document.data() as? [String: Any],
                       let name = data["name"] as? String {
                        self?.participantNames[email] = name
                        names.append(name)
                        self?.logger.log("Retrieved name for \(email): \(name)")
                    } else {
                        names.append(email) // Fallback to email if name is not found
                        self?.logger.log("No name found for \(email), using email as fallback", level: .warning)
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.logger.log("Completed retrieving \(names.count) participant names")
            completion(names)
        }
    }
    
    @MainActor
    func getUserProfilePic(email: String) async -> String? {
        logger.log("Fetching profile picture for: \(email)")
        do {
            let document = try await db.collection("users").document(email).getDocument()
            if let data = document.data(),
               let profilePictureUrl = data["profilePictureUrl"] as? String {
                logger.log("Found profile picture URL for \(email)")
                return profilePictureUrl
            }
            logger.log("No profile picture found for \(email)", level: .info)
            return nil
        } catch {
            logger.log("Error fetching profile picture: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
    
    func stopListening() {
        logger.log("Stopping chat list listener")
        listener?.remove()
    }
    
    deinit {
        stopListening()
    }
    
    // Update the app badge count based on unread messages
    func updateAppBadge() {
        guard let currentUserEmail = Auth.auth().currentUser?.email else { return }
        
        // Count unread messages across all chats
        let unreadCount = self.chats.reduce(0) { count, chat in
            return count + (chat.hasUnreadMessages(for: currentUserEmail) ? 1 : 0)
        }
        
        logger.log("Updating app badge count to \(unreadCount)")
        
        // Update the app badge count
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = unreadCount
        }
    }
}
