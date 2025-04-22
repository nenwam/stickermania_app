//
//  CustomerChatTopicsViewModel.swift
//  Sticker Mania App
//
//  Created by Connor on 4/18/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// Define a struct to hold user and their unread status
struct CustomerChatTopicInfo: Identifiable, Hashable {
    let user: User
    let hasUnreadMessages: Bool
    var id: String { user.id } // Use user's ID as the identifier
    
    // Conform to Hashable based on user's ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(user.id)
    }
    
    static func == (lhs: CustomerChatTopicInfo, rhs: CustomerChatTopicInfo) -> Bool {
        lhs.user.id == rhs.user.id
    }
}

class CustomerChatTopicsViewModel: ObservableObject {
    // Publish the new struct array
    @Published var customerTopicInfos: [CustomerChatTopicInfo] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let logger = LoggingService.shared
    private var userFetchTasks: [String: Task<Void, Never>] = [:]

    init() {
        fetchCustomerChats()
    }

    deinit {
        listener?.remove()
        userFetchTasks.values.forEach { $0.cancel() }
        logger.log("Deinitializing CustomerChatTopicsViewModel and removing listener")
    }

    // Add a force refresh method that can be called from the pull-to-refresh
    func forceRefreshCustomerChats() {
        // Remove existing listener if active
        listener?.remove()
        listener = nil
        // Clear any existing tasks
        userFetchTasks.values.forEach { $0.cancel() }
        userFetchTasks.removeAll()
        // Now fetch fresh data
        fetchCustomerChats()
        logger.log("Force refreshing customer chats")
    }

    func fetchCustomerChats() {
        // Prevent re-attaching listener if already active
        guard listener == nil else {
            logger.log("Listener already active, skipping fetchCustomerChats.")
            return
        }
        
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            logger.log("No user email found for fetching chats", level: .error)
            self.error = NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
            return
        }

        isLoading = true
        logger.log("Fetching customer chats for user: \(currentUserEmail)")

        // Update the query to include ordering by lastMessageTimestamp to ensure
        // we always get updates when new messages arrive
        let query = db.collection("chats")
            .whereField("participants", arrayContains: currentUserEmail)
            .order(by: "lastMessageTimestamp", descending: true)

        listener = query.addSnapshotListener { [weak self] (snapshot: QuerySnapshot?, error: Error?) in
            guard let self = self else { return }
            
            self.logger.log("🔔 CustomerChatTopicsViewModel: Firestore listener triggered!")
            
            if let error = error {
                self.error = error
                self.isLoading = false
                self.logger.log("Error fetching chats: \(error.localizedDescription)", level: .error)
                return
            }

            guard let documents = snapshot?.documents else {
                self.logger.log("No chat documents found", level: .info)
                self.isLoading = false
                return
            }

            // Check if this is due to an unread status change or a new message
            if let changedDocs = snapshot?.documentChanges {
                for change in changedDocs {
                    if let chatData = change.document.data() as? [String: Any],
                       let unreadStatus = chatData["unreadStatus"] as? [String: Bool] {
                        self.logger.log("🔄 Chat document changed: \(change.document.documentID), type: \(change.type.rawValue)")
                        self.logger.log("🔄 Unread status: \(unreadStatus)")
                    }
                }
            }

            self.logger.log("Retrieved \(documents.count) chats involving user \(currentUserEmail)")

            Task {
                var customerUnreadStatus: [String: Bool] = [:]
                var customerEmailsInChats = Set<String>()
                var customerLastMessage: [String: Date] = [:] // Track most recent message

                // First pass: collect all customers and their unread status
                for document in documents {
                    guard let chat = Chat(document: document) else {
                        self.logger.log("Skipping chat document due to parsing error: \(document.documentID)", level: .warning)
                        continue
                    }

                    // Find the customer participant
                    guard let customerEmail = chat.participants.first(where: { $0 != currentUserEmail }) else {
                        self.logger.log("Skipping chat document as no other participant found: \(document.documentID)", level: .warning)
                        continue
                    }
                    
                    // Track all customers involved
                    customerEmailsInChats.insert(customerEmail)
                    
                    // Check if this chat has unread messages for the current user
                    let isChatUnread = chat.hasUnreadMessages(for: currentUserEmail)
                    self.logger.log("Chat \(chat.id) with \(customerEmail) has unread status: \(isChatUnread)")
                    
                    // Update the overall unread status for this customer - if any chat is unread, mark as unread
                    if isChatUnread {
                        customerUnreadStatus[customerEmail] = true
                    } else if customerUnreadStatus[customerEmail] == nil {
                        // Only set to false if we haven't seen this customer yet or no chat is unread
                        customerUnreadStatus[customerEmail] = false
                    }
                    
                    // Track the most recent message timestamp per customer
                    if let lastMessageTime = customerLastMessage[customerEmail] {
                        if chat.lastMessage.timestamp > lastMessageTime {
                            customerLastMessage[customerEmail] = chat.lastMessage.timestamp
                        }
                    } else {
                        customerLastMessage[customerEmail] = chat.lastMessage.timestamp
                    }
                }

                // Now fetch the User objects for all unique customers found
                var fetchedTopicInfos = Set<CustomerChatTopicInfo>()
                
                for customerEmail in customerEmailsInChats {
                    // Avoid fetching the same user multiple times if already fetching
                    if self.userFetchTasks[customerEmail] == nil {
                        let task = Task {
                            do {
                                if let user = try await self.fetchUser(email: customerEmail), user.role == .customer {
                                    let hasUnread = customerUnreadStatus[customerEmail] ?? false
                                    let topicInfo = CustomerChatTopicInfo(user: user, hasUnreadMessages: hasUnread)
                                    
                                    await MainActor.run { // Update the set on the main thread
                                        fetchedTopicInfos.insert(topicInfo)
                                    }
                                }
                            } catch {
                                await MainActor.run {
                                    self.error = error
                                    self.logger.log("Error fetching user \(customerEmail): \(error.localizedDescription)", level: .error)
                                }
                            }
                            await MainActor.run {
                                self.userFetchTasks[customerEmail] = nil
                            }
                        }
                        self.userFetchTasks[customerEmail] = task
                    }
                }

                // Wait for all fetch tasks to complete
                await Task.waitForAll(self.userFetchTasks.values.map { $0 }) 
                
                // Update the published property on the main thread
                await MainActor.run {
                    // Sort results by most recent chat activity (most recent first)
                    self.customerTopicInfos = Array(fetchedTopicInfos).sorted { 
                        let timestamp1 = customerLastMessage[$0.user.email] ?? Date.distantPast
                        let timestamp2 = customerLastMessage[$1.user.email] ?? Date.distantPast
                        return timestamp1 > timestamp2
                    }
                    self.isLoading = false
                    
                    // Log out the unread statuses
                    for topic in self.customerTopicInfos {
                        self.logger.log("Customer \(topic.user.name) (\(topic.user.email)) has unread: \(topic.hasUnreadMessages)")
                    }
                    
                    self.logger.log("Finished processing chats. Found \(self.customerTopicInfos.count) customer chat topics.")
                }
            }
        }
    }

    private func fetchUser(email: String) async throws -> User? {
        logger.log("Fetching user details for: \(email)")
        let userDocumentRef = db.collection("users").document(email)

        do {
            let documentSnapshot = try await userDocumentRef.getDocument()
            let user = try documentSnapshot.data(as: User.self)
            logger.log("Successfully fetched user: \(user.name) (Role: \(user.role))")
            return user
        } catch let decodingError as DecodingError {
             logger.log("Decoding error for user \(email): \(decodingError)", level: .error)
             throw decodingError
         } catch {
            if (error as NSError).code == 5 { // Firestore error code for 'Not Found'
                 logger.log("User document not found for email: \(email)", level: .warning)
                 return nil
             } else {
                 logger.log("Error fetching user document \(email): \(error.localizedDescription)", level: .error)
                 throw error
             }
        }
    }
}

// Helper extension for Task.waitForAll (if not available in your Swift version)
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension Task where Success == Never, Failure == Never {
    static func waitForAll<T>(_ tasks: [Task<T, Error>]) async throws -> [T] {
        try await withThrowingTaskGroup(of: T.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            var results = [T]()
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    // Overload for tasks that don't return a value (Void)
    static func waitForAll(_ tasks: [Task<Void, Never>]) async {
        await withTaskGroup(of: Void.self) { group in
            for task in tasks {
                group.addTask { await task.value }
            }
            // Wait for all tasks in the group to complete
            for await _ in group {}
        }
    }
}
