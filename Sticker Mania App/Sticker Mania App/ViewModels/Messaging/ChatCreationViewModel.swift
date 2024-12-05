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
    
    init() {
        fetchAvailableParticipants()
    }
    
    func fetchAvailableParticipants() {
        isLoading = true
        
        // Query users collection to get available participants
        db.collection("users").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.error = error
                return
            }
            
            if let documents = snapshot?.documents {
                self.availableParticipants = documents.compactMap { doc -> String? in
                    return doc.data()["email"] as? String
                }
            }
        }
    }
    
    func createChat(participants: [String], title: String, chatType: ChatType) {
        isLoading = true
        
        var allParticipants = participants
        let currentUserEmail = Auth.auth().currentUser?.email ?? ""
        if !allParticipants.contains(currentUserEmail) {
            allParticipants.append(currentUserEmail)
        }
        
        // Initialize unread status for each participant
        var unreadStatus: [String: Bool] = [:]
        for participant in allParticipants {
            unreadStatus[participant] = participant != currentUserEmail
        }
        
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
        
        db.collection("chats").addDocument(data: chatData) { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.error = error
                return
            }
        }
    }
    
    func toggleParticipant(_ participantId: String) {
        if selectedParticipants.contains(participantId) {
            selectedParticipants.removeAll { $0 == participantId }
        } else {
            selectedParticipants.append(participantId)
        }
    }
}