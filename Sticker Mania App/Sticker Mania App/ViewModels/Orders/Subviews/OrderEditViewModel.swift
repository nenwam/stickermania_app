import SwiftUI

class OrderEditViewModel: ObservableObject {
    @Published var status: OrderStatus
    @Published var items: [OrderItem]
    @Published var errorMessage: IdentifiableError?
    private let orderEditController = OrderEditController()
    private let orderId: String

    init(order: Order) {
        self.status = order.status
        self.items = order.items
        self.orderId = order.id
    }

    var totalAmount: Double {
        items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
    }

    func validateItems() -> Bool {
        for item in items {
            if item.name.isEmpty || item.quantity <= 0 || item.price < 0 {
                errorMessage = IdentifiableError(message: "Invalid item details")
                return false
            }
        }
        errorMessage = nil
        return true
    }

    func saveChanges(onSave: @escaping (OrderStatus, [OrderItem]) -> Void) {
        guard validateItems() else { return }
        
        let updates: [String: Any] = [
            "status": status.rawValue,
            "items": items.map { [
                "id": $0.id,
                "name": $0.name,
                "quantity": $0.quantity,
                "price": $0.price
            ]},
            "totalAmount": totalAmount // Include total amount in updates
        ]
        
        orderEditController.updateOrder(orderId: orderId, updates: updates) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    onSave(self?.status ?? .pending, self?.items ?? [])
                case .failure(let error):
                    self?.errorMessage = IdentifiableError(message: error.localizedDescription)
                }
            }
        }
    }
}