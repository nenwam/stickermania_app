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
                    return doc.documentID
                }
            }
        }
    }
    
    func createChat(participants: [String], initialMessage: String, chatType: ChatType) {
    isLoading = true
    
    var allParticipants = participants
    let currentUserId = Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? ""
    if !allParticipants.contains(currentUserId) {
        allParticipants.append(currentUserId)
    }
    
    // Initialize unread status for each participant
    var unreadStatus: [String: Bool] = [:]
    for participant in allParticipants {
        unreadStatus[participant] = participant != currentUserId
    }
    
    let messageData: [String: Any] = [
        "id": UUID().uuidString,
        "senderId": currentUserId,
        "text": initialMessage,
        "timestamp": Timestamp()
    ]
    
    let chatData: [String: Any] = [
        "participants": allParticipants,
        "lastMessage": messageData,
        "lastMessageTimestamp": Timestamp(),
        "createdAt": Timestamp(),
        "type": chatType.rawValue,
        "unreadStatus": unreadStatus // Use dictionary for unread status
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