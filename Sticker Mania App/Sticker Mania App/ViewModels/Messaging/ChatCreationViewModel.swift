//
//  ChatCreationViewModel.swift
//  Sticker Mania App
//
//  Created by Connor on 10/30/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class ChatCreationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var availableParticipants: [String] = [] // List of users that can be added
    @Published var selectedParticipants: [String] = []
    
    private let db = Firestore.firestore()
    private let logger = LoggingService.shared
    
    init() {
        logger.log("Initializing ChatCreationViewModel")
        fetchAvailableParticipants()
    }
    
    func fetchAvailableParticipants() {
        logger.log("Fetching available participants")
        isLoading = true
        
        // Query users collection to get available participants
        db.collection("users").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.logger.log("Error fetching participants: \(error.localizedDescription)", level: .error)
                self.error = error
                return
            }
            
            if let documents = snapshot?.documents {
                self.availableParticipants = documents.compactMap { doc -> String? in
                    return doc.data()["email"] as? String
                }
                self.logger.log("Successfully fetched \(self.availableParticipants.count) participants")
            }
        }
    }
    
    func createChat(participants: [String], title: String, chatType: ChatType) {
        logger.log("Creating new chat with title: \(title), type: \(chatType.rawValue), participants count: \(participants.count)")
        isLoading = true
        
        var allParticipants = participants
        let currentUserEmail = Auth.auth().currentUser?.email ?? ""
        if !allParticipants.contains(currentUserEmail) {
            allParticipants.append(currentUserEmail)
            logger.log("Added current user to participants list")
        }
        
        // Initialize unread status for each participant
        var unreadStatus: [String: Bool] = [:]
        for participant in allParticipants {
            unreadStatus[participant] = participant != currentUserEmail
        }
        
        let chatId = UUID().uuidString
        let messageData: [String: Any] = [
            "id": UUID().uuidString,
            "senderId": currentUserEmail,
            "text": "Chat created",
            "timestamp": Timestamp()
        ]
        
        let chatData: [String: Any] = [
            "participants": allParticipants,
            "lastMessage": messageData,
            "lastMessageTimestamp": Timestamp(),
            "createdAt": Timestamp(),
            "type": chatType.rawValue,
            "unreadStatus": unreadStatus,
            "title": title
        ]
        
        logger.log("Saving chat to Firestore with ID: \(chatId)")
        db.collection("chats").addDocument(data: chatData) { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.logger.log("Error creating chat: \(error.localizedDescription)", level: .error)
                self.error = error
                return
            }
            
            self.logger.log("Chat successfully created")
        }
    }
    
    func toggleParticipant(_ participantId: String) {
        if selectedParticipants.contains(participantId) {
            selectedParticipants.removeAll { $0 == participantId }
            logger.log("Removed participant: \(participantId)", level: .info)
        } else {
            selectedParticipants.append(participantId)
            logger.log("Added participant: \(participantId)", level: .info)
        }
    }
}