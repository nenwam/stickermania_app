import SwiftUI
import FirebaseFirestore

class OrderCreationViewModel: ObservableObject {
    @Published var customerId = ""
    @Published var brandId = ""
    @Published var brandName = ""
    @Published var items: [OrderItem] = []
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var createdOrder: Order?  // Add this property
    @Published var brands: [Brand] = [] // State variable for brands
    @Published var selectedBrand: Brand? // State variable for selected brand

    private let controller = OrderCreationController()
    private let orderController = OrderListController()
    
    var totalAmount: Double {
        items.reduce(0) { total, item in
            if item.productType == .tax {
                return total
            }
            return total + (item.price * Double(item.quantity))
        }
    }
    
    var isValid: Bool {
        !customerId.isEmpty && !items.isEmpty && !brandId.isEmpty && !brandName.isEmpty
    }
    
    func addItem(_ item: OrderItem) {
        items.append(item)
    }
    
    func removeItem(at index: Int) {
        items.remove(at: index)
    }
    
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
                    self?.showError = true
                    self?.errorMessage = error.localizedDescription
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
                case .failure(let error):
                    self?.showError = true
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func createOrder() -> Order? {
        guard isValid else { return nil }
        
        let order = Order(
            id: UUID().uuidString,
            customerId: customerId,
            accountManagerId: "", // TODO: Add account manager ID
            brandId: brandId,
            brandName: brandName,
            items: items,
            status: .pending,
            createdAt: Date(),
            totalAmount: totalAmount
        )
        
        controller.createOrder(order) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.createdOrder = order  // Set the created order
                    self?.fetchOrders(forCustomerId: self?.customerId ?? "")
                case .failure(let error):
                    self?.showError = true
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
        
        return order
    }

    // Function to fetch brands for a selected customer
    func fetchBrands(for customerId: String) {
        print("Fetching brands for customer ID: \(customerId)")
        let db = Firestore.firestore()
        db.collection("users").document(customerId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching customer brands: \(error)")
                return
            }
            
            guard let data = snapshot?.data() else {
                print("No data found for customer ID: \(customerId)")
                self.brands = []
                self.selectedBrand = nil
                return
            }
            
            guard let brandsList = data["brands"] as? [[String: Any]] else {
                print("No brands array found in customer data: \(data)")
                self.brands = []
                self.selectedBrand = nil
                return
            }
            
            print("Found \(brandsList.count) brands in customer data")
            
            var extractedBrands: [Brand] = []
            for brandDict in brandsList {
                print("Processing brand: \(brandDict)")
                if let id = brandDict["id"] as? String,
                   let name = brandDict["name"] as? String {
                    let brand = Brand(id: id, name: name)
                    extractedBrands.append(brand)
                    print("Successfully created brand: \(name) with ID: \(id)")
                } else {
                    print("Failed to extract brand from dictionary: \(brandDict)")
                }
            }
            
            self.brands = extractedBrands
            self.selectedBrand = self.brands.first
            print("Final brands count: \(self.brands.count)")
            if let first = self.selectedBrand {
                print("Selected first brand: \(first.name)")
            }
        }
    }
}