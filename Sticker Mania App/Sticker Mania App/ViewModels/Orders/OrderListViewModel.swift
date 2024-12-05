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
    
    func fetchOrders() {
        isLoading = true
        errorMessage = nil
        
        orderController.fetchOrders { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let orders):
                    self?.orders = orders
                case .failure(let error):
                    self?.errorMessage = IdentifiableError(message: error.localizedDescription)
                }
            }
        }
    }
    
    func fetchOrders(forCustomerId customerId: String) {
        isLoading = true
        errorMessage = nil
        
        orderController.fetchOrders(forCustomerId: customerId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let orders):
                    self?.orders = orders
                    // Fetch customer name from first order if available
                    if let firstOrder = orders.first {
                        self?.customerName = firstOrder.customerEmail
                    }
                case .failure(let error):
                    self?.errorMessage = IdentifiableError(message: error.localizedDescription)
                }
            }
        }
    }
    
    func fetchBrands(forCustomerId customerId: String) {
        isLoading = true
        errorMessage = nil
        
        db.collection("users").document(customerId).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = IdentifiableError(message: error.localizedDescription)
                    return
                }
                
                guard let data = snapshot?.data(),
                      let brandsList = data["brands"] as? [[String: Any]] else {
                    self?.brands = []
                    return
                }
                
                let extractedBrands = brandsList.compactMap { brandDict -> Brand? in
                    guard let id = brandDict["id"] as? String,
                          let name = brandDict["name"] as? String else {
                        return nil
                    }
                    return Brand(id: id, name: name)
                }
                
                self?.brands = extractedBrands
            }
        }
    }
}
