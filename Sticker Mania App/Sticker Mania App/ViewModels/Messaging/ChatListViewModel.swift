import FirebaseFirestore
import FirebaseAuth
import UIKit

class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var participantNames: [String: String] = [:] // Cache for participant names
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let logger = LoggingService.shared
    
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