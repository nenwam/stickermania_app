import FirebaseFirestore

class OrderCreationController {
    private let db = Firestore.firestore()
    
    func createOrder(_ order: Order, completion: @escaping (Result<Void, Error>) -> Void) {
        let orderData: [String: Any] = [
            "customerId": order.customerId,
            "accountManagerId": order.accountManagerId,
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
            "totalAmount": order.totalAmount
        ]
        
        db.collection("orders").document(order.id).setData(orderData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
