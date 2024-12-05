import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
class ChatDetailViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoadingMore = false
    @Published var hasMoreMessages = true
    @Published var participants: [User] = []
    @Published var chatType: ChatType = .team
    @Published var participantNames: [String: String] = [:] // Cache for participant names
    
    private var lastDocument: DocumentSnapshot?
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    func startListening(chatId: String) {
        let query = db.collection("chats")
            .document(chatId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
        
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else {
                print("Error fetching messages: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.messages = documents.compactMap { document in
                try? document.data(as: ChatMessage.self)
            }.reversed()
            
            self.lastDocument = documents.last
            self.hasMoreMessages = !documents.isEmpty

            // Check if the current user is not the sender of the last message
            if let lastMessage = self.messages.last, lastMessage.senderId != Auth.auth().currentUser?.email {
                // Mark messages as read asynchronously
                Task {
                    await self.updateUnreadStatus(chatId: chatId)
                }
            }
        }
        
        // Fetch participants and chat type
        db.collection("chats").document(chatId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data(),
                  let participantEmails = data["participants"] as? [String],
                  let chatTypeString = data["type"] as? String else {
                print("Error fetching chat data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            print("Participant emails: \(participantEmails)")
            
            // Set chat type
            DispatchQueue.main.async {
                self.chatType = chatTypeString == "team" ? .team : .customer
            }
            
            // Fetch each participant's user data
            for participantEmail in participantEmails {
                db.collection("users").document(participantEmail).getDocument { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error fetching participant data: \(error.localizedDescription)")
                        return
                    }
                    
                    print("Fetching participant data for email: \(participantEmail)")
                    
                    if let userData = try? snapshot?.data(as: User.self) {
                        DispatchQueue.main.async {
                            // Check if participant already exists before adding
                            let participantExists = self.participants.contains { $0.email.trimmingCharacters(in: .whitespaces).lowercased() == userData.email.trimmingCharacters(in: .whitespaces).lowercased() }
                            
                            if !participantExists {
                                self.participants.append(userData)
                                print("Successfully added participant: \(userData.email)")
                            } else {
                                print("Participant already exists: \(userData.email)")
                            }
                        }
                    } else {
                        print("Failed to decode user data for: \(participantEmail)")
                    }
                }
            }

            
        }
    }

    func getParticipants(for participantIds: [String], completion: @escaping ([User]) -> Void) {
        var participants: [User] = []
        let dispatchGroup = DispatchGroup()
        
        for email in participantIds {
            dispatchGroup.enter()
            db.collection("users").document(email).getDocument { snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    print("Error fetching participant data: \(error.localizedDescription)")
                    return
                }
                
                if let userData = try? snapshot?.data(as: User.self) {
                    participants.append(userData)
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(participants)
        }
    }

    func updateUnreadStatus(chatId: String) async {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("Error: No user is signed in.")
            return
        }
        
        do {
            // Fetch the current chat document
            let chatDocument = try await db.collection("chats").document(chatId).getDocument()
            
            if var chatData = chatDocument.data() {
                var unreadStatus = chatData["unreadStatus"] as? [String: Bool] ?? [:]
                
                // Mark messages as read for the current user
                unreadStatus[currentUserEmail] = false
                
                // Update the chat document with the new unreadStatus
                try await db.collection("chats")
                    .document(chatId)
                    .updateData(["unreadStatus": unreadStatus])
            }
        } catch {
            print("Error updating unread status: \(error.localizedDescription)")
        }
    }
    
    func loadMoreMessages(chatId: String) async {
        guard let lastDocument = lastDocument, !isLoadingMore else { return }
        
        isLoadingMore = true
        
        do {
            let snapshot = try await db.collection("chats")
                .document(chatId)
                .collection("messages")
                .order(by: "timestamp", descending: true)
                .limit(to: 20)
                .start(afterDocument: lastDocument)
                .getDocuments()
            
            let newMessages = snapshot.documents.compactMap { document in
                try? document.data(as: ChatMessage.self)
            }
            
            DispatchQueue.main.async {
                self.messages.insert(contentsOf: newMessages.reversed(), at: 0)
                self.lastDocument = snapshot.documents.last
                self.hasMoreMessages = !snapshot.documents.isEmpty
                self.isLoadingMore = false
            }
        } catch {
            print("Error loading more messages: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isLoadingMore = false
            }
        }
    }
    
    func sendMessage(_ text: String, chatId: String) async {
        guard !text.isEmpty else { return }

        // Safely unwrap the email
        guard let email = Auth.auth().currentUser?.email else {
            print("Error: No user is signed in.")
            return
        }
        
        let message = ChatMessage(
            id: UUID().uuidString,
            senderId: email,
            text: text,
            mediaUrl: nil,
            mediaType: nil,
            timestamp: Date()
        )
        
        do {
            // Add the message to the messages subcollection
            try await db.collection("chats")
                .document(chatId)
                .collection("messages")
                .document(message.id)
                .setData(from: message)
            
            // Fetch the current chat document to update unreadStatus
            let chatDocument = try await db.collection("chats").document(chatId).getDocument()
            
            if var chatData = chatDocument.data() {
                var unreadStatus = chatData["unreadStatus"] as? [String: Bool] ?? [:]
                
                // Update unreadStatus for all participants except the sender
                for participant in unreadStatus.keys {
                    unreadStatus[participant] = (participant != email)
                }
                
                // Update the chat document with the new unreadStatus and lastMessage
                try await db.collection("chats")
                    .document(chatId)
                    .updateData([
                        "lastMessage": [
                            "id": message.id,
                            "senderId": message.senderId,
                            "text": message.text,
                            "timestamp": Timestamp(date: message.timestamp)
                        ],
                        "lastMessageTimestamp": Timestamp(date: message.timestamp),
                        "unreadStatus": unreadStatus
                    ])
            }
        } catch {
            print("Error sending message: \(error.localizedDescription)")
        }
    }

    func sendImage(_ imageData: Data, chatId: String) async {
        guard !imageData.isEmpty else {
            print("Error: Image data is empty.")
            return
        }
        
        guard let email = Auth.auth().currentUser?.email else {
            print("Error: No user is signed in.")
            return
        }
        
        let storageRef = Storage.storage().reference()
        print("Storage reference", storageRef)
        let imageRef = storageRef.child("chatImages/\(UUID().uuidString).jpg")
        
        do {
            // Upload image data to Firebase Storage
            print("Uploading metadata")
            let metadata = try await imageRef.putDataAsync(imageData, metadata: nil)
            
            // Ensure the upload was successful
            guard metadata != nil else {
                print("Error: Upload metadata is nil.")
                return
            }
            
            // Get the download URL
            let downloadURL = try await imageRef.downloadURL()
            
            // Create a ChatMessage with the image URL
            let message = ChatMessage(
                id: UUID().uuidString,
                senderId: email,
                text: nil,
                mediaUrl: downloadURL.absoluteString,
                mediaType: .image,
                timestamp: Date()
            )
            
            // Add the message to the messages subcollection
            try await db.collection("chats")
                .document(chatId)
                .collection("messages")
                .document(message.id)
                .setData(from: message)
            
            // Update the chat document with the new unreadStatus and lastMessage
            let chatDocument = try await db.collection("chats").document(chatId).getDocument()
            
            if var chatData = chatDocument.data() {
                var unreadStatus = chatData["unreadStatus"] as? [String: Bool] ?? [:]
                
                // Update unreadStatus for all participants except the sender
                for participant in unreadStatus.keys {
                    unreadStatus[participant] = (participant != email)
                }
                
                try await db.collection("chats")
                    .document(chatId)
                    .updateData([
                        "lastMessage": [
                            "id": message.id,
                            "senderId": message.senderId,
                            "text": "Image",
                            "mediaUrl": message.mediaUrl ?? "",
                            "mediaType": message.mediaType?.rawValue ?? "",
                            "timestamp": Timestamp(date: message.timestamp)
                        ],
                        "lastMessageTimestamp": Timestamp(date: message.timestamp),
                        "unreadStatus": unreadStatus
                    ])
            }
        } catch {
            print("Error sending image: \(error.localizedDescription)")
        }
    }

    func sendVideo(_ videoData: Data, chatId: String) async {
        guard !videoData.isEmpty else {
            print("Error: Video data is empty.")
            return
        }
        
        guard let email = Auth.auth().currentUser?.email else {
            print("Error: No user is signed in.")
            return
        }
        
        let storageRef = Storage.storage().reference()
        let videoRef = storageRef.child("chatVideos/\(UUID().uuidString).mp4")
        
        do {
            // Upload video data to Firebase Storage
            print("Uploading video data...")
            let metadata = try await videoRef.putDataAsync(videoData, metadata: nil)
            
            // Ensure the upload was successful
            guard metadata != nil else {
                print("Error: Upload metadata is nil.")
                return
            }
            
            // Get the download URL
            let downloadURL = try await videoRef.downloadURL()
            print("Video uploaded successfully: \(downloadURL)")
            
            // Create a ChatMessage with the video URL
            let message = ChatMessage(
                id: UUID().uuidString,
                senderId: email,
                text: nil,
                mediaUrl: downloadURL.absoluteString,
                mediaType: .video,
                timestamp: Date()
            )
            
            // Add the message to the messages subcollection
            try await db.collection("chats")
                .document(chatId)
                .collection("messages")
                .document(message.id)
                .setData(from: message)
            
            // Update the chat document with the new unreadStatus and lastMessage
            let chatDocument = try await db.collection("chats").document(chatId).getDocument()
            
            if var chatData = chatDocument.data() {
                var unreadStatus = chatData["unreadStatus"] as? [String: Bool] ?? [:]
                
                // Update unreadStatus for all participants except the sender
                for participant in unreadStatus.keys {
                    unreadStatus[participant] = (participant != email)
                }
                
                try await db.collection("chats")
                    .document(chatId)
                    .updateData([
                        "lastMessage": [
                            "id": message.id,
                            "senderId": message.senderId,
                            "text": "Video",
                            "mediaUrl": message.mediaUrl ?? "",
                            "mediaType": message.mediaType?.rawValue ?? "",
                            "timestamp": Timestamp(date: message.timestamp)
                        ],
                        "lastMessageTimestamp": Timestamp(date: message.timestamp),
                        "unreadStatus": unreadStatus
                    ])
            }
        } catch {
            print("Error sending video: \(error.localizedDescription)")
        }
    }
    
    func sendPDF(_ pdfData: Data, chatId: String) async {
        guard !pdfData.isEmpty else {
            print("Error: PDF data is empty.")
            return
        }
        
        guard let email = Auth.auth().currentUser?.email else {
            print("Error: No user is signed in.")
            return
        }
        
        let storageRef = Storage.storage().reference()
        let pdfRef = storageRef.child("chatPDFs/\(UUID().uuidString).pdf")
        
        do {
            // Upload PDF data to Firebase Storage
            print("Uploading PDF data...")
            let metadata = try await pdfRef.putDataAsync(pdfData, metadata: nil)
            
            // Ensure the upload was successful
            guard metadata != nil else {
                print("Error: Upload metadata is nil.")
                return
            }
            
            // Get the download URL
            let downloadURL = try await pdfRef.downloadURL()
            print("PDF uploaded successfully: \(downloadURL)")
            
            // Create a ChatMessage with the PDF URL
            let message = ChatMessage(
                id: UUID().uuidString,
                senderId: email,
                text: nil,
                mediaUrl: downloadURL.absoluteString,
                mediaType: .pdf,
                timestamp: Date()
            )
            
            // Add the message to the messages subcollection
            try await db.collection("chats")
                .document(chatId)
                .collection("messages")
                .document(message.id)
                .setData(from: message)
            
            // Update the chat document with the new unreadStatus and lastMessage
            let chatDocument = try await db.collection("chats").document(chatId).getDocument()
            
            if var chatData = chatDocument.data() {
                var unreadStatus = chatData["unreadStatus"] as? [String: Bool] ?? [:]
                
                // Update unreadStatus for all participants except the sender
                for participant in unreadStatus.keys {
                    unreadStatus[participant] = (participant != email)
                }
                
                try await db.collection("chats")
                    .document(chatId)
                    .updateData([
                        "lastMessage": [
                            "id": message.id,
                            "senderId": message.senderId,
                            "text": "PDF",
                            "mediaUrl": message.mediaUrl ?? "",
                            "mediaType": message.mediaType?.rawValue ?? "",
                            "timestamp": Timestamp(date: message.timestamp)
                        ],
                        "lastMessageTimestamp": Timestamp(date: message.timestamp),
                        "unreadStatus": unreadStatus
                    ])
            }
        } catch {
            print("Error sending PDF: \(error.localizedDescription)")
        }
    }
    
    func stopListening() {
        listener?.remove()
    }
}