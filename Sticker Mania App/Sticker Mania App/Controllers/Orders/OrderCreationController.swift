import FirebaseFirestore

class OrderCreationController {
    private let db = Firestore.firestore()
    
    func createOrder(_ order: Order, completion: @escaping (Result<Void, Error>) -> Void) {
        var orderData: [String: Any] = [
            "customerEmail": order.customerEmail,
            "accountManagerEmail": order.accountManagerEmail,
            "brandId": order.brandId,
            "brandName": order.brandName,
            "items": order.items.map { item in
                [
                    "id": item.id,
                    "name": item.name,
                    "quantity": item.quantity,
                    "price": item.price,
                    "productType": item.productType.rawValue
                ]
            },
            "status": order.status.rawValue,
            "createdAt": Timestamp(date: order.createdAt),
            "totalAmount": order.totalAmount,
            "attachments": order.attachments.map { attachment in
                [
                    "id": attachment.id,
                    "url": attachment.url,
                    "type": attachment.type.rawValue,
                    "name": attachment.name
                ]
            }
        ]
        
        // Add customerUid if available
        if let customerUid = order.customerUid {
            orderData["customerUid"] = customerUid
        }
        
        // Add customerName if available
        if let customerName = order.customerName {
            orderData["customerName"] = customerName
        }
        
        db.collection("orders").document(order.id).setData(orderData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
