//
//  CustomerChatListViewModel.swift
//  Sticker Mania App
//
//  Created by Connor on 4/18/25.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth

class CustomerChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var participantNames: [String: String] = [:] // Cache for participant names
    @Published var canDeleteChats = false // New property to track if user can delete chats
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let logger = LoggingService.shared
    
    // The customer ID whose chats we want to display
    private var customerId: String
    
    init(customerId: String) {
        self.customerId = customerId
        fetchChats()
        checkUserPermissions() // Check permissions during initialization
    }
    
    deinit {
        listener?.remove()
        logger.log("Removing chat listener for customer: \(customerId)")
    }
    
    func fetchChats() {
        isLoading = true
        logger.log("Fetching chats for customer: \(customerId)")
        
        // Get current user's email - must be a participant
        guard let currentUserEmail = Auth.auth().currentUser?.email else { 
            logger.log("No user email found for fetching chats", level: .error)
            isLoading = false
            error = NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
            return 
        }
        
        // We need two conditions:
        // 1. The current user is a participant
        // 2. The specified customer is a participant
        // 
        // Firestore doesn't support AND queries with arrayContains,
        // so we'll query for chats where current user is a participant,
        // then filter client-side for the customer
        
        let query = db.collection("chats")
            .whereField("participants", arrayContains: currentUserEmail)
            .order(by: "lastMessageTimestamp", descending: true)
        
        logger.log("Starting customer chat listener for \(currentUserEmail) and customer \(customerId)")
        
        listener = query.addSnapshotListener { [weak self] (snapshot, error) in
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
            
            self.logger.log("Retrieved \(documents.count) raw chats for filtering")
            
            // Convert to Chat objects
            var customerChats: [Chat] = []
            
            for document in documents {
                // Use the failable initializer from the Chat model
                if let chat = Chat(document: document) {
                    // Check if this chat includes the customer we're filtering for
                    if chat.participants.contains(self.customerId) {
                        customerChats.append(chat)
                    }
                }
            }
            
            self.chats = customerChats
            self.logger.log("Filtered to \(customerChats.count) chats involving customer \(self.customerId)")
        }
    }
    
    // Function to get participant names for a chat
    func getParticipantNames(for participants: [String], completion: @escaping ([String]) -> Void) {
        var names: [String] = []
        let group = DispatchGroup()
        
        for participantEmail in participants {
            // Check if we already have the name cached
            if let cachedName = participantNames[participantEmail] {
                names.append(cachedName)
                continue
            }
            
            group.enter()
            db.collection("users").document(participantEmail).getDocument { [weak self] (document, error) in
                defer { group.leave() }
                guard let self = self, let document = document, document.exists else {
                    // Handle error or document not existing if needed
                    self?.logger.log("Document for \(participantEmail) not found or error: \(error?.localizedDescription ?? "Unknown error")", level: .warning)
                    // Add participantEmail as fallback name when user document is missing
                    names.append(participantEmail)
                    self?.participantNames[participantEmail] = participantEmail
                    return
                }
                
                // Try decoding the User struct first
                if let userData = try? document.data(as: User.self) {
                    // Since User.name is likely non-optional, access it directly
                    let name = userData.name 
                    names.append(name)
                    self.participantNames[participantEmail] = name // Cache the name
                } else if let name = document.data()?["name"] as? String {
                     // Fallback: If User decoding fails, try getting name directly from data dict
                    names.append(name)
                    self.participantNames[participantEmail] = name // Cache the name
                } else {
                     // Final fallback: Use the email if name cannot be found either way
                    names.append(participantEmail) 
                    self.participantNames[participantEmail] = participantEmail
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(names)
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
                self.chats.remove(at: index)
            }
            
            self.logger.log("Successfully deleted chat with ID: \(chatId)")
        }
    }
    
    // Function to check if current user has permission to delete chats
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
}
