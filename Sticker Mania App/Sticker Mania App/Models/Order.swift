import Foundation
import FirebaseFirestore

struct Order {
    let id: String
    let customerEmail: String
    let accountManagerEmail: String
    var brandId: String
    var brandName: String
    var items: [OrderItem]
    var status: OrderStatus
    let createdAt: Date
    var totalAmount: Double
    var attachments: [OrderAttachment]
}

struct OrderAttachment: Identifiable {
    let id: String
    let url: String
    let type: AttachmentType
    let name: String
    
    enum AttachmentType: String {
        case pdf
        case image
        case video
    }
}

func saveOrder(order: Order) {
    let orderRef = db.collection("orders").document(order.id)
    
    var attachmentsData: [[String: Any]] = []
    for attachment in order.attachments {
        attachmentsData.append([
            "id": attachment.id,
            "url": attachment.url,
            "type": attachment.type.rawValue,
            "name": attachment.name
        ])
    }
    
    orderRef.setData([
        "customerEmail": order.customerEmail,
        "accountManagerEmail": order.accountManagerEmail,
        "brandId": order.brandId,
        "brandName": order.brandName,
        "status": order.status.rawValue,
        "totalAmount": order.totalAmount,
        "createdDate": order.createdAt,
        "attachments": attachmentsData
    ]) { error in
        if let error = error {
            print("Error saving order: \(error)")
        } else {
            print("Order saved successfully")
        }
    }
}