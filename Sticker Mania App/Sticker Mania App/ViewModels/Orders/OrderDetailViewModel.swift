import SwiftUI
import FirebaseFirestore

class OrderDetailViewModel: ObservableObject {
    @Published var order: Order
    private let db = Firestore.firestore()
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let orderDetailController = OrderDetailController()
    
    init(order: Order) {
        self.order = order
    }

    func updateOrder(withStatus status: OrderStatus, items: [OrderItem]) {
        order.status = status
        order.items = items
        order.totalAmount = items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
    }
    
    func updateOrderStatus(_ newStatus: OrderStatus) {
        isLoading = true
        errorMessage = nil
        
        let orderRef = db.collection("orders").document(order.id)
        orderRef.updateData([
            "status": newStatus.rawValue
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.order = Order(
                        id: self?.order.id ?? "",
                        customerId: self?.order.customerId ?? "",
                        accountManagerId: self?.order.accountManagerId ?? "",
                        brandId: self?.order.brandId ?? "",
                        brandName: self?.order.brandName ?? "",
                        items: self?.order.items ?? [],
                        status: newStatus,
                        createdAt: self?.order.createdAt ?? Date(),
                        totalAmount: self?.order.totalAmount ?? 0.0
                    )
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
                
                let updatedOrder = Order(
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
                
                self?.order = updatedOrder
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
                    // Optionally refresh order details or update local order state
                    self?.refreshOrderDetails()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
