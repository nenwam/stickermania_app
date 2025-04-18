import FirebaseFirestore
import FirebaseAuth

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
                    
                    let attachments = (data["attachments"] as? [[String: Any]] ?? []).compactMap { attachmentData -> OrderAttachment? in
                        guard let id = attachmentData["id"] as? String,
                              let url = attachmentData["url"] as? String,
                              let typeString = attachmentData["type"] as? String,
                              let type = OrderAttachment.AttachmentType(rawValue: typeString),
                              let name = attachmentData["name"] as? String else {
                            return nil
                        }
                        return OrderAttachment(id: id, url: url, type: type, name: name)
                    }
                    
                    return Order(
                        id: document.documentID,
                        customerEmail: data["customerEmail"] as? String ?? "",
                        customerUid: data["customerUid"] as? String,
                        accountManagerEmail: data["accountManagerEmail"] as? String ?? "",
                        brandId: data["brandId"] as? String ?? "",
                        brandName: data["brandName"] as? String ?? "",
                        customerName: data["customerName"] as? String,
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
                        totalAmount: data["totalAmount"] as? Double ?? 0.0,
                        attachments: attachments
                    )
                }
                
                completion(.success(orders))
            }
    }
    
    func fetchOrders(forCustomerId customerEmail: String, completion: @escaping (Result<[Order], Error>) -> Void) {
        // Try to get current user UID
        let currentUser = Auth.auth().currentUser
        
        // If we have a current user and their email matches the requested one, use UID for query
        if let currentUser = currentUser, currentUser.email == customerEmail {
            fetchOrdersByUid(uid: currentUser.uid, email: customerEmail, completion: completion)
        } else {
            // Otherwise use the email-based query
            fetchOrdersByEmail(email: customerEmail, completion: completion)
        }
    }
    
    private func fetchOrdersByUid(uid: String, email: String, completion: @escaping (Result<[Order], Error>) -> Void) {
        print("Fetching orders by UID: \(uid)")
        db.collection("orders")
            .whereField("customerUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                // If no orders found with UID or there's an error, fall back to email
                if error != nil || (snapshot?.documents.isEmpty ?? true) {
                    print("No orders found by UID or error: \(error?.localizedDescription ?? "No orders"). Falling back to email.")
                    self?.fetchOrdersByEmail(email: email, completion: completion)
                    return
                }
                
                self?.processOrderDocuments(snapshot, completion: completion)
            }
    }
    
    private func fetchOrdersByEmail(email: String, completion: @escaping (Result<[Order], Error>) -> Void) {
        print("Fetching orders by email: \(email)")
        db.collection("orders")
            .whereField("customerEmail", isEqualTo: email)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
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
                
                self?.processOrderDocuments(snapshot, completion: completion)
            }
    }
    
    private func processOrderDocuments(_ snapshot: QuerySnapshot?, completion: @escaping (Result<[Order], Error>) -> Void) {
        guard let documents = snapshot?.documents else {
            completion(.success([]))
            return
        }
        
        let orders = documents.compactMap { document -> Order? in
            let data = document.data()
            
            let attachments = (data["attachments"] as? [[String: Any]] ?? []).compactMap { attachmentData -> OrderAttachment? in
                guard let id = attachmentData["id"] as? String,
                      let url = attachmentData["url"] as? String,
                      let typeString = attachmentData["type"] as? String,
                      let type = OrderAttachment.AttachmentType(rawValue: typeString),
                      let name = attachmentData["name"] as? String else {
                    return nil
                }
                return OrderAttachment(id: id, url: url, type: type, name: name)
            }
            
            return Order(
                id: document.documentID,
                customerEmail: data["customerEmail"] as? String ?? "",
                customerUid: data["customerUid"] as? String,
                accountManagerEmail: data["accountManagerEmail"] as? String ?? "",
                brandId: data["brandId"] as? String ?? "",
                brandName: data["brandName"] as? String ?? "",
                customerName: data["customerName"] as? String,
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
                totalAmount: data["totalAmount"] as? Double ?? 0.0,
                attachments: attachments
            )
        }
        
        completion(.success(orders))
    }
    
    func fetchBrands(forCustomerId customerEmail: String, completion: @escaping (Result<[Brand], Error>) -> Void) {
        db.collection("users")
            .document(customerEmail)
            .getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let document = snapshot, document.exists,
                      let data = document.data(),
                      let brandsData = data["brands"] as? [[String: Any]] else {
                    completion(.success([]))
                    return
                }
                
                let brands = brandsData.compactMap { brandData -> Brand? in
                    guard let id = brandData["id"] as? String,
                          let name = brandData["name"] as? String else {
                        return nil
                    }
                    return Brand(id: id, name: name)
                }
                
                completion(.success(brands))
            }
    }
    
    func fetchRecentOrders(limit: Int, completion: @escaping (Result<[Order], Error>) -> Void) {
        db.collection("orders")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                self?.processOrderDocuments(snapshot, completion: completion)
            }
    }
}
