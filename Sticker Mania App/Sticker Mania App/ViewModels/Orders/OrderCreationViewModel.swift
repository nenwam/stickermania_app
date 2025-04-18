import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

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
    private let logger = LoggingService.shared
    
    var totalAmount: Double {
        let total = items.reduce(0) { total, item in
            if item.productType == .tax {
                return total
            }
            return total + (item.price * Double(item.quantity))
        }
        logger.log("Calculated total order amount: \(total)")
        return total
    }
    
    var isValid: Bool {
        if (customerId.isEmpty) {
            logger.log("Validation failed: Customer ID is empty", level: .warning)
        }
        if (items.isEmpty) {
            logger.log("Validation failed: No items in order", level: .warning)
        }
        if (brandId.isEmpty) {
            logger.log("Validation failed: Brand ID is empty", level: .warning)
        }
        if (brandName.isEmpty) {
            logger.log("Validation failed: Brand name is empty", level: .warning)
        }
        let valid = !customerId.isEmpty && !items.isEmpty
        logger.log("Order validation result: \(valid)")
        return valid
    }
    
    func addItem(_ item: OrderItem) {
        logger.log("Adding item to order: \(item.name), quantity: \(item.quantity), price: \(item.price)")
        items.append(item)
    }
    
    func removeItem(at index: Int) {
        if index < items.count {
            logger.log("Removing item from order: \(items[index].name)")
            items.remove(at: index)
        } else {
            logger.log("Failed to remove item: Invalid index \(index)", level: .error)
        }
    }
    
    func addAttachment(_ attachment: OrderAttachment) {
        logger.log("Adding attachment to order: \(attachment.name), type: \(attachment.type.rawValue)")
        attachments.append(attachment)
    }
    
    func removeAttachment(at index: Int) {
        if index < attachments.count {
            logger.log("Removing attachment from order: \(attachments[index].name)")
            attachments.remove(at: index)
        } else {
            logger.log("Failed to remove attachment: Invalid index \(index)", level: .error)
        }
    }
    
    func uploadAttachment(_ data: Data, type: OrderAttachment.AttachmentType, name: String, completion: @escaping (Result<OrderAttachment, Error>) -> Void) {
        logger.log("Uploading attachment: \(name), type: \(type.rawValue), size: \(data.count) bytes")
        let storageRef = storage.reference()
        let fileName = "\(UUID().uuidString)_\(name)"
        let fileExtension = type == .image ? "jpg" : "pdf"
        let path = "orders/\(customerId)/attachments/\(fileName).\(fileExtension)"
        let fileRef = storageRef.child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = type == .image ? "image/jpeg" : "application/pdf"
        
        logger.log("Starting upload to path: \(path)")
        fileRef.putData(data, metadata: metadata) { [weak self] metadata, error in
            if let error = error {
                self?.logger.log("Attachment upload failed: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
                return
            }
            
            self?.logger.log("Attachment uploaded, retrieving download URL")
            fileRef.downloadURL { [weak self] url, error in
                if let error = error {
                    self?.logger.log("Failed to get download URL: \(error.localizedDescription)", level: .error)
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    let errorMessage = "Failed to get download URL"
                    self?.logger.log(errorMessage, level: .error)
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    return
                }
                
                let attachment = OrderAttachment(
                    id: UUID().uuidString,
                    url: downloadURL.absoluteString,
                    type: type,
                    name: name
                )
                
                self?.logger.log("Attachment uploaded successfully: \(name), URL: \(downloadURL.absoluteString)")
                completion(.success(attachment))
            }
        }
    }
    
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
                    self?.showError = true
                    self?.errorMessage = error.localizedDescription
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
                case .failure(let error):
                    self?.logger.log("Failed to fetch orders for customer: \(error.localizedDescription)", level: .error)
                    self?.showError = true
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func createOrder() {
        logger.log("Creating new order for customer: \(customerId), brand: \(brandName)")
        isLoading = true
        errorMessage = nil
        
        // Make sure we have the brand info from selectedBrand if available
        if let selected = selectedBrand {
            brandId = selected.id
            brandName = selected.name
            logger.log("Using selected brand: \(selected.name) (ID: \(selected.id))")
        } else {
            logger.log("No brand selected, using current values: \(brandName) (ID: \(brandId))", level: .warning)
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "User not authenticated"
            logger.log("Order creation failed: User not authenticated", level: .error)
            return
        }
        
        let timestamp = Date()
        let fileURLs = attachments.map { $0.url }
        let uuid = UUID().uuidString
        
        // Get current user's UID for new orders
        let customerUid = currentUser.uid
        
        // Fetch the customer name from the users collection
        let db = Firestore.firestore()
        db.collection("users").document(customerId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            var customerName: String? = nil
            if let data = snapshot?.data(), let name = data["name"] as? String {
                customerName = name
                self.logger.log("Found customer name: \(name)")
            } else {
                self.logger.log("Could not find customer name for email: \(self.customerId)", level: .warning)
            }
            
            self.logger.log("Preparing order with ID: \(uuid), items: \(self.items.count), attachments: \(self.attachments.count)")
            let order = Order(
                id: uuid,
                customerEmail: self.customerId,
                customerUid: customerUid,
                accountManagerEmail: "", // Empty for now
                brandId: self.brandId,
                brandName: self.brandName,
                customerName: customerName,
                items: self.items,
                status: .pending, // Use the enum value instead of string
                createdAt: timestamp,
                totalAmount: self.totalAmount,
                attachments: self.attachments
            )
            
            // Use the controller we defined as a property
            self.logger.log("Submitting order to database")
            self.controller.createOrder(order) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    switch result {
                    case .success:
                        self?.logger.log("Order created successfully: \(uuid)")
                        self?.createdOrder = order
                        self?.fetchOrders(forCustomerId: self?.customerId ?? "")
                    case .failure(let error):
                        self?.logger.log("Order creation failed: \(error.localizedDescription)", level: .error)
                        self?.showError = true
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func fetchBrands(for customerId: String) {
        logger.log("Fetching brands for customer: \(customerId)")
        let db = Firestore.firestore()
        db.collection("users").document(customerId).getDocument { [weak self] snapshot, error in
            if let error = error {
                self?.logger.log("Error fetching customer brands: \(error.localizedDescription)", level: .error)
                return
            }
            
            guard let data = snapshot?.data() else {
                self?.logger.log("No data found for customer ID: \(customerId)", level: .warning)
                self?.brands = []
                self?.selectedBrand = nil
                self?.brandId = ""
                self?.brandName = ""
                return
            }
            
            guard let brandsList = data["brands"] as? [[String: Any]] else {
                self?.logger.log("No brands array found in customer data", level: .warning)
                self?.brands = []
                self?.selectedBrand = nil
                self?.brandId = ""
                self?.brandName = ""
                return
            }
            
            self?.logger.log("Found \(brandsList.count) brands for customer: \(customerId)")
            
            var extractedBrands: [Brand] = []
            for brandDict in brandsList {
                if let id = brandDict["id"] as? String,
                   let name = brandDict["name"] as? String {
                    let brand = Brand(id: id, name: name)
                    extractedBrands.append(brand)
                    self?.logger.log("Processed brand: \(name) with ID: \(id)")
                } else {
                    self?.logger.log("Failed to extract brand from data", level: .warning)
                }
            }
            
            self?.brands = extractedBrands
            
            // Set the first brand as the selected brand
            if let firstBrand = extractedBrands.first {
                self?.selectedBrand = firstBrand
                self?.brandId = firstBrand.id
                self?.brandName = firstBrand.name
                self?.logger.log("Auto-selected default brand: \(firstBrand.name) with ID: \(firstBrand.id)")
            } else {
                self?.selectedBrand = nil
                self?.brandId = ""
                self?.brandName = ""
                self?.logger.log("No brands available to select", level: .warning)
            }
        }
    }
}