//
//  UserStatisticsViewModel.swift
//  Sticker Mania App
//
//  Created by Connor on 12/2/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class UserStatisticsViewModel: ObservableObject {
    @Published var totalSpent: Double = 0.0
    @Published var completedOrdersCount: Int = 0
    @Published var inProgressOrdersCount: Int = 0
    @Published var mostOrderedItems: [(name: String, count: Int)] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private let logger = LoggingService.shared
    
    func loadStatistics() async {
        guard let userEmail = Auth.auth().currentUser?.email else {
            logger.log("No user email found when loading statistics", level: .warning)
            return
        }
        
        logger.log("Loading statistics for user: \(userEmail)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get all orders for user
            logger.log("Fetching orders from Firestore for user: \(userEmail)")
            let ordersSnapshot = try await db.collection("orders")
                .whereField("customerEmail", isEqualTo: userEmail)
                .getDocuments()
            
            logger.log("Found \(ordersSnapshot.documents.count) orders for statistics")
            
            // Calculate totals
            var total = 0.0
            var completed = 0
            var inProgress = 0
            var itemCounts: [String: Int] = [:]
            
            for doc in ordersSnapshot.documents {
                let data = doc.data()
                logger.log("Processing order \(doc.documentID) for statistics")
                
                // Add to total spent
                if let amount = data["totalAmount"] as? Double {
                    total += amount
                    logger.log("Added amount \(amount) to total spent")
                }
                
                // Count order status
                if let status = data["status"] as? String {
                    logger.log("Order status: \(status)")
                    if status == "completed" {
                        completed += 1
                    } else if status == "inProgress" {
                        inProgress += 1
                    }
                }
                
                // Count items ordered, excluding tax and discount items
                if let items = data["items"] as? [[String: Any]] {
                    logger.log("Processing \(items.count) items in order \(doc.documentID)")
                    for item in items {
                        if let name = item["name"] as? String,
                           name.lowercased() != "tax" && name.lowercased() != "discount" {
                            itemCounts[name, default: 0] += 1
                            logger.log("Incremented count for item: \(name)", level: .debug)
                        }
                    }
                }
            }
            
            // Update published properties
            logger.log("Updating statistics: total=$\(String(format: "%.2f", total)), completed=\(completed), inProgress=\(inProgress)")
            self.totalSpent = total
            self.completedOrdersCount = completed
            self.inProgressOrdersCount = inProgress
            
            // Get top 3 most ordered items
            logger.log("Calculating top 3 most ordered items from \(itemCounts.count) unique items")
            self.mostOrderedItems = itemCounts
                .map { (name: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
                .prefix(3)
                .map { (name: $0.name, count: $0.count) }
            
            logger.log("Statistics loaded successfully for user: \(userEmail)")
            
        } catch {
            logger.log("Error loading statistics: \(error.localizedDescription)", level: .error)
            self.error = error
        }
    }
    
    func formatCurrency(_ amount: Double) -> String {
        logger.log("Formatting currency amount: \(amount)", level: .debug)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        let result = formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
        return result
    }
}
