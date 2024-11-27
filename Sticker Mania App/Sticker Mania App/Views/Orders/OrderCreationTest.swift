//
//  OrderCreationTest.swift
//  Sticker Mania App
//
//  Created by Connor on 10/29/24.
//

import SwiftUI
import FirebaseFirestore

struct OrderCreationTest: View {
    @State private var showOrderList = false
    @State private var customerId = ""
    private let db = Firestore.firestore()
    
    func createTestOrder() {
        let testOrder = [
            "customerId": customerId,
            "accountManagerId": "testManager",
            "items": [
                [
                    "id": UUID().uuidString,
                    "name": "Test Sticker Pack",
                    "quantity": 2,
                    "price": 9.99
                ],
                [
                    "id": UUID().uuidString,
                    "name": "Custom Test Sticker",
                    "quantity": 1,
                    "price": 4.99
                ]
            ],
            "status": OrderStatus.pending.rawValue,
            "createdAt": Timestamp(date: Date()),
            "totalAmount": 24.97
        ] as [String : Any]
        
        db.collection("orders").addDocument(data: testOrder)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Customer ID", text: $customerId)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                Button("Create Test Order") {
                    createTestOrder()
                    showOrderList = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(customerId.isEmpty)
                
                NavigationLink(destination: OrderListView(customerId: customerId).onAppear {
                    // Pass the customerId to OrderListView
                    EmptyView()
                }, isActive: $showOrderList) {
                    EmptyView()
                }
            }
        }
    }
}

#Preview {
    OrderCreationTest()
}
