import SwiftUI
import FirebaseFirestore
import FirebaseStorage

class OrderCreationViewModel: ObservableObject {
    @Published var customerId = ""
    @Published var brandId = ""
    @Published var brandName = ""
    @Published var items: [OrderItem] = []
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var createdOrder: Order?
    @Published var brands: [Brand] = []
    @Published var selectedBrand: Brand?
    @Published var attachments: [OrderAttachment] = []

    private let controller = OrderCreationController()
    private let orderController = OrderListController()
    private let storage = Storage.storage()
    
    var totalAmount: Double {
        items.reduce(0) { total, item in
            if item.productType == .tax {
                return total
            }
            return total + (item.price * Double(item.quantity))
        }
    }
    
    var isValid: Bool {
        if (customerId.isEmpty) {
            print("Customer ID is empty")
        }
        if (items.isEmpty) {
            print("Items are empty")
        }
        if (brandId.isEmpty) {
            print("Brand ID is empty")
        }
        if (brandName.isEmpty) {
            print("Brand name is empty")
        }
        return !customerId.isEmpty && !items.isEmpty
    }
    
    func addItem(_ item: OrderItem) {
        items.append(item)
    }
    
    func removeItem(at index: Int) {
        items.remove(at: index)
    }
    
    func addAttachment(_ attachment: OrderAttachment) {
        attachments.append(attachment)
    }
    
    func removeAttachment(at index: Int) {
        attachments.remove(at: index)
    }
    
    func uploadAttachment(_ data: Data, type: OrderAttachment.AttachmentType, name: String, completion: @escaping (Result<OrderAttachment, Error>) -> Void) {
        let storageRef = storage.reference()
        let fileName = "\(UUID().uuidString)_\(name)"
        let fileExtension = type == .image ? "jpg" : "pdf"
        let path = "orders/\(customerId)/attachments/\(fileName).\(fileExtension)"
        let fileRef = storageRef.child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = type == .image ? "image/jpeg" : "application/pdf"
        
        fileRef.putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            fileRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    return
                }
                
                let attachment = OrderAttachment(
                    id: UUID().uuidString,
                    url: downloadURL.absoluteString,
                    type: type,
                    name: name
                )
                
                completion(.success(attachment))
            }
        }
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
            customerEmail: customerId,
            accountManagerEmail: "", // TODO: Add account manager email
            brandId: brandId,
            brandName: brandName,
            items: items,
            status: .pending,
            createdAt: Date(),
            totalAmount: totalAmount,
            attachments: attachments
        )
        
        controller.createOrder(order) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.createdOrder = order
                    self?.fetchOrders(forCustomerId: self?.customerId ?? "")
                case .failure(let error):
                    self?.showError = true
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
        
        return order
    }

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