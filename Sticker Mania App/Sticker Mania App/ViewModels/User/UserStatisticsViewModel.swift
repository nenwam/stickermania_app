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
    
    func loadStatistics() async {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("DEBUG: No user email found")
            return
        }
        
        print("DEBUG: Loading statistics for user: \(userEmail)")
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get all orders for user
            print("DEBUG: Fetching orders from Firestore")
            let ordersSnapshot = try await db.collection("orders")
                .whereField("customerEmail", isEqualTo: userEmail)
                .getDocuments()
            
            print("DEBUG: Found \(ordersSnapshot.documents.count) orders")
            
            // Calculate totals
            var total = 0.0
            var completed = 0
            var inProgress = 0
            var itemCounts: [String: Int] = [:]
            
            for doc in ordersSnapshot.documents {
                let data = doc.data()
                print("DEBUG: Processing order \(doc.documentID)")
                
                // Add to total spent
                if let amount = data["totalAmount"] as? Double {
                    total += amount
                    print("DEBUG: Added amount \(amount) to total")
                }
                
                // Count order status
                if let status = data["status"] as? String {
                    print("DEBUG: Order status: \(status)")
                    if status == "completed" {
                        completed += 1
                    } else if status == "inProgress" {
                        inProgress += 1
                    }
                }
                
                // Count items ordered, excluding tax and discount items
                if let items = data["items"] as? [[String: Any]] {
                    print("DEBUG: Processing \(items.count) items in order")
                    for item in items {
                        if let name = item["name"] as? String,
                           name.lowercased() != "tax" && name.lowercased() != "discount" {
                            itemCounts[name, default: 0] += 1
                            print("DEBUG: Incremented count for item: \(name)")
                        }
                    }
                }
            }
            
            // Update published properties
            print("DEBUG: Updating published properties")
            self.totalSpent = total
            self.completedOrdersCount = completed
            self.inProgressOrdersCount = inProgress
            
            // Get top 3 most ordered items
            print("DEBUG: Calculating top 3 most ordered items")
            self.mostOrderedItems = itemCounts
                .map { (name: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
                .prefix(3)
                .map { (name: $0.name, count: $0.count) }
            
            print("DEBUG: Statistics loaded successfully")
            
        } catch {
            print("DEBUG: Error loading statistics: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    func formatCurrency(_ amount: Double) -> String {
        print("DEBUG: Formatting currency amount: \(amount)")
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        let result = formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
        print("DEBUG: Formatted amount: \(result)")
        return result
    }
}
