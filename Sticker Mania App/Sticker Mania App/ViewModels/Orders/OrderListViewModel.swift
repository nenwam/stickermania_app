import SwiftUI
import FirebaseFirestore

class OrderListViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: IdentifiableError?
    @Published var customerName: String?
    @Published var brands: [Brand] = []
    
    private let orderController = OrderListController()
    private let db = Firestore.firestore()
    private let logger = LoggingService.shared
    
    func fetchOrders() {
        logger.log("Fetching all orders")
        isLoading = true
        errorMessage = nil
        
        orderController.fetchOrders { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let orders):
                    self?.logger.log("Successfully fetched \(orders.count) orders")
                    self?.orders = orders
                case .failure(let error):
                    self?.logger.log("Failed to fetch orders: \(error.localizedDescription)", level: .error)
                    self?.errorMessage = IdentifiableError(message: error.localizedDescription)
                }
            }
        }
    }
    
    func fetchOrders(forCustomerId customerId: String) {
        logger.log("Fetching orders for customer: \(customerId)")
        isLoading = true
        errorMessage = nil
        
        orderController.fetchOrders(forCustomerId: customerId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let orders):
                    self?.logger.log("Successfully fetched \(orders.count) orders for customer: \(customerId)")
                    self?.orders = orders
                    // Fetch customer name from first order if available
                    if let firstOrder = orders.first {
                        self?.customerName = firstOrder.customerEmail
                        self?.logger.log("Set customer name to: \(firstOrder.customerEmail)")
                    } else {
                        self?.logger.log("No orders found for customer: \(customerId)", level: .info)
                    }
                case .failure(let error):
                    self?.logger.log("Failed to fetch orders for customer: \(error.localizedDescription)", level: .error)
                    self?.errorMessage = IdentifiableError(message: error.localizedDescription)
                }
            }
        }
    }
    
    func fetchBrands(forCustomerId customerId: String) {
        logger.log("Fetching brands for customer: \(customerId)")
        isLoading = true
        errorMessage = nil
        
        db.collection("users").document(customerId).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.logger.log("Error fetching brands: \(error.localizedDescription)", level: .error)
                    self?.errorMessage = IdentifiableError(message: error.localizedDescription)
                    return
                }
                
                guard let data = snapshot?.data(),
                      let brandsList = data["brands"] as? [[String: Any]] else {
                    self?.logger.log("No brands found for customer: \(customerId)", level: .info)
                    self?.brands = []
                    return
                }
                
                let extractedBrands = brandsList.compactMap { brandDict -> Brand? in
                    guard let id = brandDict["id"] as? String,
                          let name = brandDict["name"] as? String else {
                        self?.logger.log("Invalid brand data found", level: .warning)
                        return nil
                    }
                    return Brand(id: id, name: name)
                }
                
                self?.logger.log("Successfully fetched \(extractedBrands.count) brands for customer: \(customerId)")
                self?.brands = extractedBrands
            }
        }
    }
}
