import FirebaseFirestore

class OrderEditController {
    private let db = Firestore.firestore()

    func updateOrder(orderId: String, updates: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        let orderRef = db.collection("orders").document(orderId)
        orderRef.updateData(updates) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}