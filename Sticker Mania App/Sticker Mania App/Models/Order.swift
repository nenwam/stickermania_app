import Foundation
import FirebaseFirestore

struct Order {
    let id: String
    let customerId: String
    let accountManagerId: String
    var brandId: String
    var brandName: String
    var items: [OrderItem]
    var status: OrderStatus
    let createdAt: Date
    var totalAmount: Double
}

func saveOrder(order: Order) {
    let orderRef = db.collection("orders").document(order.id)
    orderRef.setData([
        "customerId": order.customerId,
        "accountManagerId": order.accountManagerId,
        "brandId": order.brandId,
        "brandName": order.brandName,
        "status": order.status.rawValue,
        "totalAmount": order.totalAmount,
        "createdDate": order.createdAt
    ]) { error in
        if let error = error {
            print("Error saving order: \(error)")
        } else {
            print("Order saved successfully")
        }
    }
}