import FirebaseFirestore

class OrderListController {
    private let db = Firestore.firestore()
    
    func fetchOrders(completion: @escaping (Result<[Order], Error>) -> Void) {
        db.collection("orders")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {

                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let orders = documents.compactMap { document -> Order? in
                    let data = document.data()
                    return Order(
                        id: document.documentID,
                        customerId: data["customerId"] as? String ?? "",
                        accountManagerId: data["accountManagerId"] as? String ?? "",
                        brandId: data["brandId"] as? String ?? "",
                        brandName: data["brandName"] as? String ?? "",
                        items: (data["items"] as? [[String: Any]] ?? []).compactMap { itemData in
                            OrderItem(
                                id: itemData["id"] as? String ?? "",
                                name: itemData["name"] as? String ?? "",
                                quantity: itemData["quantity"] as? Int ?? 0,
                                price: itemData["price"] as? Double ?? 0.0,
                                productType: ProductType(rawValue: itemData["productType"] as? String ?? "") ?? .sticker
                            )
                        },
                        status: OrderStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        totalAmount: data["totalAmount"] as? Double ?? 0.0
                    )
                }
                
                completion(.success(orders))
            }
    }
    
    func fetchOrders(forCustomerId customerId: String, completion: @escaping (Result<[Order], Error>) -> Void) {
        db.collection("orders")
            .whereField("customerId", isEqualTo: customerId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    // Print the error message to the console
                    print("Error fetching documents: \(error.localizedDescription)")
                    
                    // If the error is a Firestore error, print the full error
                    if let firestoreError = error as NSError? {
                        print("Firestore error: \(firestoreError)")
                    }

                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let orders = documents.compactMap { document -> Order? in
                    let data = document.data()
                    return Order(
                        id: document.documentID,
                        customerId: data["customerId"] as? String ?? "",
                        accountManagerId: data["accountManagerId"] as? String ?? "",
                        brandId: data["brandId"] as? String ?? "",
                        brandName: data["brandName"] as? String ?? "",
                        items: (data["items"] as? [[String: Any]] ?? []).compactMap { itemData in
                            OrderItem(
                                id: itemData["id"] as? String ?? "",
                                name: itemData["name"] as? String ?? "",
                                quantity: itemData["quantity"] as? Int ?? 0,
                                price: itemData["price"] as? Double ?? 0.0,
                                productType: ProductType(rawValue: itemData["productType"] as? String ?? "") ?? .sticker
                            )
                        },
                        status: OrderStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        totalAmount: data["totalAmount"] as? Double ?? 0.0
                    )
                }
                
                completion(.success(orders))
            }
    }
}
