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
    @Published var canDeleteOrder: Bool = false
    private let logger = LoggingService.shared
    
    init(order: Order) {
        self.order = order
        logger.log("Initialized OrderDetailViewModel for order: \(order.id)")
        checkIfCustomer()
        checkUserPermissions()
    }
    
    private func checkUserPermissions() {
        guard let currentUser = Auth.auth().currentUser, 
              let email = currentUser.email else {
            logger.log("No current user found when checking permissions", level: .error)
            return
        }
        
        logger.log("Checking delete permissions for user: \(email)")
        
        db.collection("users").document(email).getDocument { [weak self] document, error in
            guard let self = self, let document = document, document.exists else {
                self?.logger.log("User document not found when checking permissions", level: .error)
                return
            }
            
            if let roleString = document.data()?["role"] as? String {
                if roleString == "admin" || roleString == "accountManager" {
                    DispatchQueue.main.async {
                        self.canDeleteOrder = true
                        self.logger.log("User has delete order permissions: \(roleString)")
                    }
                } else {
                    self.logger.log("User does not have delete order permissions: \(roleString)")
                }
            }
        }
    }
    
    func deleteOrder(completion: @escaping (Bool) -> Void) {
        logger.log("Attempting to delete order with ID: \(order.id)")
        isLoading = true
        errorMessage = nil
        
        db.collection("orders").document(order.id).delete { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.logger.log("Error deleting order: \(error.localizedDescription)", level: .error)
                    self.errorMessage = "Failed to delete order: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                self.logger.log("Successfully deleted order with ID: \(self.order.id)")
                completion(true)
            }
        }
    }
    
    private func checkIfCustomer() {
        guard let currentUser = Auth.auth().currentUser else {
            logger.log("No current user found when checking customer status", level: .info)
            isCustomer = false
            return
        }
        
        isCustomer = currentUser.email == order.customerEmail
        logger.log("Customer status check: isCustomer=\(isCustomer), user=\(currentUser.email ?? "unknown"), orderCustomer=\(order.customerEmail)")
    }

    func updateOrder(withStatus status: OrderStatus, items: [OrderItem]) {
        logger.log("Updating order \(order.id) with status: \(status.rawValue) and \(items.count) items")
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
                    self?.logger.log("Successfully updated order \(self?.order.id ?? "unknown")")
                case .failure(let error):
                    self?.logger.log("Failed to update order: \(error.localizedDescription)", level: .error)
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func updateOrderStatus(_ newStatus: OrderStatus) {
        logger.log("Updating order status to: \(newStatus.rawValue) for order: \(order.id)")
        isLoading = true
        errorMessage = nil
        
        let updates = ["status": newStatus.rawValue]
        orderDetailController.editOrder(orderId: order.id, updates: updates) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.logger.log("Successfully updated order status to \(newStatus.rawValue)")
                    self?.order.status = newStatus
                case .failure(let error):
                    self?.logger.log("Failed to update order status: \(error.localizedDescription)", level: .error)
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func refreshOrderDetails() {
        logger.log("Refreshing order details for order: \(order.id)")
        isLoading = true
        errorMessage = nil
        
        let orderRef = db.collection("orders").document(order.id)
        orderRef.getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.logger.log("Error refreshing order details: \(error.localizedDescription)", level: .error)
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let document = document, document.exists,
                      let data = document.data() else {
                    self?.logger.log("Order not found during refresh: \(self?.order.id ?? "unknown")", level: .error)
                    self?.errorMessage = "Order not found"
                    return
                }
                
                self?.logger.log("Successfully retrieved order document, parsing data")
                
                let attachments = (data["attachments"] as? [[String: Any]] ?? []).compactMap { attachmentData -> OrderAttachment? in
                    guard let id = attachmentData["id"] as? String,
                          let url = attachmentData["url"] as? String,
                          let typeString = attachmentData["type"] as? String,
                          let type = OrderAttachment.AttachmentType(rawValue: typeString),
                          let name = attachmentData["name"] as? String else {
                        self?.logger.log("Failed to parse attachment data", level: .warning)
                        return nil
                    }
                    return OrderAttachment(id: id, url: url, type: type, name: name)
                }
                
                self?.logger.log("Parsed \(attachments.count) attachments for order")
                
                let updatedOrder = Order(
                    id: document.documentID,
                    customerEmail: data["customerEmail"] as? String ?? "",
                    customerUid: data["customerUid"] as? String,
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
                
                let itemCount = updatedOrder.items.count
                self?.logger.log("Order refresh complete: id=\(updatedOrder.id), status=\(updatedOrder.status.rawValue), items=\(itemCount)")
                
                self?.order = updatedOrder
                self?.checkIfCustomer()
            }
        }
    }

    func editOrder(updates: [String: Any]) {
        logger.log("Editing order \(order.id) with updates: \(updates.keys.joined(separator: ", "))")
        isLoading = true
        errorMessage = nil

        orderDetailController.editOrder(orderId: order.id, updates: updates) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.logger.log("Order edit successful, refreshing details")
                    self?.refreshOrderDetails()
                case .failure(let error):
                    self?.logger.log("Failed to edit order: \(error.localizedDescription)", level: .error)
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
