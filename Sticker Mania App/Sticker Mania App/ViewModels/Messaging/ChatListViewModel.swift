import FirebaseFirestore
import FirebaseAuth

class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var participantNames: [String: String] = [:] // Cache for participant names
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func fetchChats() {
        isLoading = true
        
        // Query chats where current user is a participant
        let currentUserId = Auth.auth().currentUser?.email
        let userId = currentUserId?.components(separatedBy: "@").first ?? ""
        
        let query = db.collection("chats")
            .whereField("participants", arrayContains: userId)
            .order(by: "lastMessageTimestamp", descending: true)
        
        listener = query.addSnapshotListener { [weak self] (snapshot: QuerySnapshot?, error: Error?) in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.error = error
                print("Error fetching chats: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No documents found")
                return
            }
            
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
                
                return Chat(
                    id: document.documentID,
                    participants: participants,
                    lastMessage: lastMessage,
                    type: type,
                    unreadStatus: unreadStatus
                )
            }
        }
    }
    
    func getParticipantNames(for participantIds: [String], completion: @escaping ([String]) -> Void) {
        var names: [String] = []
        let dispatchGroup = DispatchGroup()
        
        for participantId in participantIds {
            if let cachedName = participantNames[participantId] {
                names.append(cachedName)
            } else {
                dispatchGroup.enter()
                db.collection("users").document(participantId).getDocument { [weak self] snapshot, error in
                    defer { dispatchGroup.leave() }
                    
                    if let error = error {
                        print("Error fetching participant data: \(error.localizedDescription)")
                        return
                    }
                    
                    if let data = snapshot?.data(), let name = data["name"] as? String {
                        self?.participantNames[participantId] = name
                        names.append(name)
                    } else {
                        names.append(participantId) // Fallback to ID if name is not found
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(names)
        }
    }
    
    func stopListening() {
        listener?.remove()
    }
    
    deinit {
        stopListening()
    }
}