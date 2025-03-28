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
    @Published var loadedOlderMessages = false // Track if older messages were loaded
    
    private var lastDocument: DocumentSnapshot?
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    private let logger = LoggingService.shared
    
    func startListening(chatId: String) {
        logger.log("Starting to listen for messages in chat: \(chatId)")
        let query = db.collection("chats")
            .document(chatId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
        
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else {
                self?.logger.log("Error fetching messages: \(error?.localizedDescription ?? "Unknown error")", level: .error)
                return
            }
            
            self.loadedOlderMessages = false // Reset this flag when receiving new messages
            self.messages = documents.compactMap { document in
                try? document.data(as: ChatMessage.self)
            }.reversed()
            
            self.lastDocument = documents.last
            self.hasMoreMessages = !documents.isEmpty
            self.logger.log("Received \(documents.count) messages for chat: \(chatId)")

            // Check if the current user is not the sender of the last message
            if let lastMessage = self.messages.last, lastMessage.senderId != Auth.auth().currentUser?.email {
                // Mark messages as read asynchronously
                Task {
                    await self.updateUnreadStatus(chatId: chatId)
                }
            }
        }
        
        // Fetch participants and chat type
        logger.log("Fetching chat data for: \(chatId)")
        db.collection("chats").document(chatId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data(),
                  let participantEmails = data["participants"] as? [String],
                  let chatTypeString = data["type"] as? String else {
                self?.logger.log("Error fetching chat data: \(error?.localizedDescription ?? "Unknown error")", level: .error)
                return
            }

            self.logger.log("Found \(participantEmails.count) participants in chat")
            
            // Set chat type
            DispatchQueue.main.async {
                self.chatType = chatTypeString == "team" ? .team : .customer
                self.logger.log("Set chat type to: \(self.chatType.rawValue)")
            }
            
            // Fetch each participant's user data
            for participantEmail in participantEmails {
                self.logger.log("Fetching participant data for: \(participantEmail)")
                db.collection("users").document(participantEmail).getDocument { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.logger.log("Error fetching participant data: \(error.localizedDescription)", level: .error)
                        return
                    }
                    
                    if let userData = try? snapshot?.data(as: User.self) {
                        DispatchQueue.main.async {
                            // Check if participant already exists before adding
                            let participantExists = self.participants.contains { $0.email.trimmingCharacters(in: .whitespaces).lowercased() == userData.email.trimmingCharacters(in: .whitespaces).lowercased() }
                            
                            if !participantExists {
                                self.participants.append(userData)
                                self.logger.log("Added participant: \(userData.email)")
                            } else {
                                self.logger.log("Participant already exists: \(userData.email)")
                            }
                        }
                    } else {
                        self.logger.log("Failed to decode user data for: \(participantEmail)", level: .error)
                    }
                }
            }
        }
    }

    func getParticipants(for participantIds: [String], completion: @escaping ([User]) -> Void) {
        logger.log("Getting participant details for \(participantIds.count) users")
        var participants: [User] = []
        let dispatchGroup = DispatchGroup()
        
        for email in participantIds {
            dispatchGroup.enter()
            db.collection("users").document(email).getDocument { [weak self] snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    self?.logger.log("Error fetching participant data: \(error.localizedDescription)", level: .error)
                    return
                }
                
                if let userData = try? snapshot?.data(as: User.self) {
                    participants.append(userData)
                    self?.logger.log("Successfully retrieved participant: \(userData.email)")
                } else {
                    self?.logger.log("Failed to decode user data for: \(email)", level: .error)
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.logger.log("Retrieved \(participants.count) participants")
            completion(participants)
        }
    }

    func updateUnreadStatus(chatId: String) async {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            logger.log("Error: No user is signed in.", level: .error)
            return
        }
        
        do {
            logger.log("Updating unread status for user: \(currentUserEmail) in chat: \(chatId)")
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
                
                logger.log("Successfully updated unread status")
            }
        } catch {
            logger.log("Error updating unread status: \(error.localizedDescription)", level: .error)
        }
    }
    
    func loadMoreMessages(chatId: String) async {
        guard let lastDocument = lastDocument, !isLoadingMore else { return }
        
        logger.log("Loading more messages for chat: \(chatId)")
        isLoadingMore = true
        loadedOlderMessages = true
        
        do {
            let snapshot = try await db.collection("chats")
                .document(chatId)
                .collection("messages")
                .order(by: "timestamp", descending: true)
                .limit(to: 10)
                .start(afterDocument: lastDocument)
                .getDocuments()
            
            let newMessages = snapshot.documents.compactMap { document in
                try? document.data(as: ChatMessage.self)
            }
            
            logger.log("Loaded \(newMessages.count) additional messages")
            
            DispatchQueue.main.async {
                self.messages.insert(contentsOf: newMessages.reversed(), at: 0)
                self.lastDocument = snapshot.documents.last
                self.hasMoreMessages = !snapshot.documents.isEmpty
                self.isLoadingMore = false
                // Don't reset loadedOlderMessages here, it will be used in the view
            }
        } catch {
            logger.log("Error loading more messages: \(error.localizedDescription)", level: .error)
            DispatchQueue.main.async {
                self.isLoadingMore = false
                self.loadedOlderMessages = false
            }
        }
    }
    
    func sendMessage(_ text: String, chatId: String) async {
        guard !text.isEmpty else { return }

        // Safely unwrap the email
        guard let email = Auth.auth().currentUser?.email else {
            logger.log("Error: No user is signed in.", level: .error)
            return
        }
        
        logger.log("Sending text message to chat: \(chatId)")
        
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
                
                // Send push notifications to other participants
                let senderName = await getUserDisplayName(email: email)
                await sendPushNotificationsToParticipants(
                    chatData["participants"] as? [String] ?? [],
                    senderName: senderName,
                    messagePreview: text,
                    chatId: chatId
                )
                
                logger.log("Successfully sent text message")
            }
        } catch {
            logger.log("Error sending message: \(error.localizedDescription)", level: .error)
        }
    }

    // Add these new methods for push notifications
    private func getUserDisplayName(email: String) async -> String {
        do {
            let userDoc = try await db.collection("users").document(email).getDocument()
            if let userData = userDoc.data(), let name = userData["name"] as? String {
                return name
            }
            return email.components(separatedBy: "@").first ?? email
        } catch {
            logger.log("Error fetching user name: \(error.localizedDescription)", level: .error)
            return email.components(separatedBy: "@").first ?? email
        }
    }

    private func sendPushNotificationsToParticipants(_ participantEmails: [String], senderName: String, messagePreview: String, chatId: String) async {
        logger.log("Preparing push notifications for chat: \(chatId)")
        
        print("Sending push notifications to \(participantEmails.count) participants")
        for recipientEmail in participantEmails {
            // Skip sending notification to the sender
            if recipientEmail == Auth.auth().currentUser?.email {
                continue
            }
            
            logger.log("Checking if user \(recipientEmail) has FCM token")
            
            // Fetch FCM token for the recipient
            do {
                let userDoc = try await db.collection("users").document(recipientEmail).getDocument()
                guard let userData = userDoc.data(), let fcmToken = userData["fcmToken"] as? String else {
                    logger.log("No FCM token found for user: \(recipientEmail)")
                    continue
                }
                
                // Create notification data
                let notificationData: [String: Any] = [
                    "token": fcmToken,
                    "notification": [
                        "title": senderName,
                        "body": messagePreview
                    ],
                    "data": [
                        "chatId": chatId,
                        "type": "message"
                    ]
                ]
                
                // Add to notifications collection to trigger Cloud Function
                try await db.collection("notifications").addDocument(data: notificationData)
                logger.log("Notification queued for \(recipientEmail)")
                print("Notification queued for \(recipientEmail)")
                
            } catch {
                logger.log("Error sending notification to \(recipientEmail): \(error.localizedDescription)", level: .error)
            }
        }
    }

    func sendImage(_ imageData: Data, chatId: String) async {
        guard !imageData.isEmpty else {
            logger.log("Error: Image data is empty.", level: .error)
            return
        }
        
        guard let email = Auth.auth().currentUser?.email else {
            logger.log("Error: No user is signed in.", level: .error)
            return
        }
        
        logger.log("Sending image to chat: \(chatId), data size: \(imageData.count) bytes")
        
        let storageRef = Storage.storage().reference()
        let imageId = UUID().uuidString
        let imageRef = storageRef.child("chatImages/\(imageId).jpg")
        
        do {
            // Upload image data to Firebase Storage
            logger.log("Uploading image to storage: \(imageId)")
            let metadata = try await imageRef.putDataAsync(imageData, metadata: nil)
            
            // Ensure the upload was successful
            guard metadata != nil else {
                logger.log("Error: Upload metadata is nil.", level: .error)
                return
            }
            
            // Get the download URL
            let downloadURL = try await imageRef.downloadURL()
            logger.log("Image upload successful, URL: \(downloadURL.absoluteString)")
            
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
                
                // Send push notifications to other participants
                let senderName = await getUserDisplayName(email: email)
                await sendPushNotificationsToParticipants(
                    chatData["participants"] as? [String] ?? [],
                    senderName: senderName,
                    messagePreview: "Image",
                    chatId: chatId
                )
                
                logger.log("Successfully sent image message")
            }
        } catch {
            logger.log("Error sending image: \(error.localizedDescription)", level: .error)
        }
    }

    func sendVideo(_ videoData: Data, chatId: String) async {
        guard !videoData.isEmpty else {
            logger.log("Error: Video data is empty.", level: .error)
            return
        }
        
        guard let email = Auth.auth().currentUser?.email else {
            logger.log("Error: No user is signed in.", level: .error)
            return
        }
        
        logger.log("Sending video to chat: \(chatId), data size: \(videoData.count) bytes")
        
        let storageRef = Storage.storage().reference()
        let videoId = UUID().uuidString
        let videoRef = storageRef.child("chatVideos/\(videoId).mp4")
        
        do {
            // Upload video data to Firebase Storage
            logger.log("Uploading video to storage: \(videoId)")
            let metadata = try await videoRef.putDataAsync(videoData, metadata: nil)
            
            // Ensure the upload was successful
            guard metadata != nil else {
                logger.log("Error: Upload metadata is nil.", level: .error)
                return
            }
            
            // Get the download URL
            let downloadURL = try await videoRef.downloadURL()
            logger.log("Video upload successful, URL: \(downloadURL.absoluteString)")
            
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
                
                // Send push notifications to other participants
                let senderName = await getUserDisplayName(email: email)
                await sendPushNotificationsToParticipants(
                    chatData["participants"] as? [String] ?? [],
                    senderName: senderName,
                    messagePreview: "Video",
                    chatId: chatId
                )
                
                logger.log("Successfully sent video message")
            }
        } catch {
            logger.log("Error sending video: \(error.localizedDescription)", level: .error)
        }
    }
    
    func sendPDF(_ pdfData: Data, chatId: String) async {
        guard !pdfData.isEmpty else {
            logger.log("Error: PDF data is empty.", level: .error)
            return
        }
        
        guard let email = Auth.auth().currentUser?.email else {
            logger.log("Error: No user is signed in.", level: .error)
            return
        }
        
        logger.log("Sending PDF to chat: \(chatId), data size: \(pdfData.count) bytes")
        
        let storageRef = Storage.storage().reference()
        let pdfId = UUID().uuidString
        let pdfRef = storageRef.child("chatPDFs/\(pdfId).pdf")
        
        do {
            // Upload PDF data to Firebase Storage
            logger.log("Uploading PDF to storage: \(pdfId)")
            let metadata = try await pdfRef.putDataAsync(pdfData, metadata: nil)
            
            // Ensure the upload was successful
            guard metadata != nil else {
                logger.log("Error: Upload metadata is nil.", level: .error)
                return
            }
            
            // Get the download URL
            let downloadURL = try await pdfRef.downloadURL()
            logger.log("PDF upload successful, URL: \(downloadURL.absoluteString)")
            
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
                
                // Send push notifications to other participants
                let senderName = await getUserDisplayName(email: email)
                await sendPushNotificationsToParticipants(
                    chatData["participants"] as? [String] ?? [],
                    senderName: senderName,
                    messagePreview: "PDF",
                    chatId: chatId
                )
                
                logger.log("Successfully sent PDF message")
            }
        } catch {
            logger.log("Error sending PDF: \(error.localizedDescription)", level: .error)
        }
    }
    
    func stopListening() {
        logger.log("Stopping message listener")
        listener?.remove()
    }

    func saveUserFCMToken(_ token: String) {
        guard let userEmail = Auth.auth().currentUser?.email else { 
            LoggingService.shared.log("No user signed in to save FCM token", level: .warning)
            return 
        }
        
        let db = Firestore.firestore()
        let userDocRef = db.collection("users").document(userEmail)
        
        // First check if document exists
        userDocRef.getDocument { snapshot, error in
            if let error = error {
                LoggingService.shared.log("Error checking user document: \(error)", level: .error)
                return
            }
            
            if snapshot?.exists == true {
                // Document exists, update it
                userDocRef.updateData(["fcmToken": token]) { error in
                    if let error = error {
                        LoggingService.shared.log("Error updating FCM token: \(error)", level: .error)
                    } else {
                        LoggingService.shared.log("FCM token updated for user: \(userEmail)")
                    }
                }
            } else {
                // Document doesn't exist, create it
                userDocRef.setData(["email": userEmail, "fcmToken": token]) { error in
                    if let error = error {
                        LoggingService.shared.log("Error creating user with FCM token: \(error)", level: .error)
                    } else {
                        LoggingService.shared.log("Created new user document with FCM token: \(userEmail)")
                    }
                }
            }
        }
    }

    
}