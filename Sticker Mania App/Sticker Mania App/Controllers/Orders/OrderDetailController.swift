import FirebaseFirestore

class OrderDetailController {
    let db = Firestore.firestore()

    func createOrder(order: Order, completion: @escaping (Result<Void, Error>) -> Void) {
        let orderRef = db.collection("orders").document(order.id)
        orderRef.setData([
            "customerId": order.customerId,
            "accountManagerId": order.accountManagerId,
            "status": order.status.rawValue,
            "items": order.items.map { [
                "id": $0.id,
                "name": $0.name,
                "quantity": $0.quantity,
                "price": $0.price,
                "productType": $0.productType.rawValue
            ]},
            "totalAmount": order.totalAmount,
            "createdAt": order.createdAt
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func updateOrder(order: Order, completion: @escaping (Result<Void, Error>) -> Void) {
        let orderRef = db.collection("orders").document(order.id)
        orderRef.updateData([
            "status": order.status.rawValue,
            "items": order.items.map { [
                "id": $0.id,
                "name": $0.name,
                "quantity": $0.quantity,
                "price": $0.price,
                "productType": $0.productType.rawValue
            ]},
            "totalAmount": order.totalAmount
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func editOrder(orderId: String, updates: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        let orderRef = db.collection("orders").document(orderId)
        orderRef.updateData(updates) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func fetchOrders(forUserId userId: String, completion: @escaping (Result<[Order], Error>) -> Void) {
        db.collection("orders").whereField("customerId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else {
                let orders = snapshot?.documents.compactMap { document -> Order? in
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
                } ?? []
                completion(.success(orders))
            }
        }
    }
}