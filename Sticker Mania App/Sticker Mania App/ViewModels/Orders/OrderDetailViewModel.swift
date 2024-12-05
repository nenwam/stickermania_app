import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class OrderDetailViewModel: ObservableObject {
    @Published var order: Order
    private let db = Firestore.firestore()
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let orderDetailController = OrderDetailController()
    @Published var isCustomer: Bool = false
    
    init(order: Order) {
        self.order = order
        checkIfCustomer()
    }
    
    private func checkIfCustomer() {
        guard let currentUser = Auth.auth().currentUser else {
            isCustomer = false
            return
        }
        
        isCustomer = currentUser.email == order.customerEmail
    }

    func updateOrder(withStatus status: OrderStatus, items: [OrderItem]) {
        order.status = status
        order.items = items
        order.totalAmount = items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
        
        isLoading = true
        errorMessage = nil
        
        orderDetailController.updateOrder(order: order) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    break
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func updateOrderStatus(_ newStatus: OrderStatus) {
        isLoading = true
        errorMessage = nil
        
        let updates = ["status": newStatus.rawValue]
        orderDetailController.editOrder(orderId: order.id, updates: updates) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.order.status = newStatus
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func refreshOrderDetails() {
        isLoading = true
        errorMessage = nil
        
        let orderRef = db.collection("orders").document(order.id)
        orderRef.getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let document = document, document.exists,
                      let data = document.data() else {
                    self?.errorMessage = "Order not found"
                    return
                }
                
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
                
                let updatedOrder = Order(
                    id: document.documentID,
                    customerEmail: data["customerEmail"] as? String ?? "",
                    accountManagerEmail: data["accountManagerEmail"] as? String ?? "",
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
                    totalAmount: data["totalAmount"] as? Double ?? 0.0,
                    attachments: attachments
                )
                
                self?.order = updatedOrder
                self?.checkIfCustomer()
            }
        }
    }

    func editOrder(updates: [String: Any]) {
        isLoading = true
        errorMessage = nil

        orderDetailController.editOrder(orderId: order.id, updates: updates) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.refreshOrderDetails()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
