import SwiftUI

class OrderEditViewModel: ObservableObject {
    @Published var status: OrderStatus
    @Published var items: [OrderItem]
    @Published var errorMessage: IdentifiableError?
    private let orderEditController = OrderEditController()
    private let orderId: String
    private let logger = LoggingService.shared

    init(order: Order) {
        self.status = order.status
        self.items = order.items
        self.orderId = order.id
        logger.log("Initialized OrderEditViewModel for order: \(order.id)")
    }

    var totalAmount: Double {
        let total = items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
        return total
    }

    func validateItems() -> Bool {
        logger.log("Validating \(items.count) items for order: \(orderId)")
        for item in items {
            if item.name.isEmpty || item.quantity <= 0 {
                logger.log("Invalid item found: name='\(item.name)', quantity=\(item.quantity)", level: .error)
                errorMessage = IdentifiableError(message: "Invalid item details")
                return false
            }
        }
        logger.log("All items validated successfully")
        errorMessage = nil
        return true
    }

    func saveChanges(onSave: @escaping (OrderStatus, [OrderItem]) -> Void) {
        logger.log("Attempting to save changes for order: \(orderId)")
        guard validateItems() else { 
            logger.log("Save cancelled due to validation failure", level: .warning)
            return 
        }
        
        let updates: [String: Any] = [
            "status": status.rawValue,
            "items": items.map { [
                "id": $0.id,
                "name": $0.name,
                "quantity": $0.quantity,
                "price": $0.price,
                "productType": $0.productType.rawValue
            ]},
            "totalAmount": totalAmount // Include total amount in updates
        ]
        
        logger.log("Sending update request to OrderEditController")
        orderEditController.updateOrder(orderId: orderId, updates: updates) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.logger.log("Successfully updated order: \(self?.orderId ?? "")")
                    onSave(self?.status ?? .pending, self?.items ?? [])
                case .failure(let error):
                    self?.logger.log("Failed to update order: \(error.localizedDescription)", level: .error)
                    self?.errorMessage = IdentifiableError(message: error.localizedDescription)
                }
            }
        }
    }
}