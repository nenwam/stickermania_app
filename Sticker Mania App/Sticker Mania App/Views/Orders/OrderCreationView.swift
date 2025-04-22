import SwiftUI
import FirebaseFirestore
import PhotosUI
import UniformTypeIdentifiers

struct OrderCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OrderCreationViewModel()
    
    // Form presentation states
    @State private var isAddItemPresented = false
    @State private var isImagePickerPresented = false
    @State private var showSuccessAlert = false
    @State private var showDocumentPicker = false
    
    // Form input states
    @State private var selectedCustomers: [String] = []
    @State private var taxAmount: String = ""
    @State private var discountAmount: String = ""
    
    // Attachment states
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedAttachmentType: OrderAttachment.AttachmentType = .image
    
    @GestureState private var scrollVelocity: CGFloat = 0

    var body: some View {
        ZStack {
            NavigationView {
                Form {
                    customerSection
                    brandSection
                        .disabled(viewModel.customerId.isEmpty)
                    orderItemsSection
                        .disabled(viewModel.customerId.isEmpty)
                    attachmentsSection
                        .disabled(viewModel.customerId.isEmpty)
                    taxSection
                        .disabled(viewModel.customerId.isEmpty)
                    discountSection
                        .disabled(viewModel.customerId.isEmpty)
                    summarySection
                }
                // .dismissKeyboardOnTapOutside()
                .addDoneButtonToKeyboard()
                .navigationTitle("Create Order")
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        leadingToolbarItems
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        trailingToolbarItems
                    }
                }
                .alert("Error", isPresented: $viewModel.showError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(viewModel.errorMessage ?? "An unknown error occurred")
                }
                .alert("Success", isPresented: $showSuccessAlert) {
                    Button("OK", role: .cancel) {
                        dismiss()
                    }
                } message: {
                    Text("Order created successfully!")
                }
                .sheet(isPresented: $isAddItemPresented) {
                    AddOrderItem { newItem in
                        viewModel.items.append(newItem)
                    }
                }
                .sheet(isPresented: $isImagePickerPresented) {
                    attachmentPickerSheet
                }
                .fileImporter(
                    isPresented: $showDocumentPicker,
                    allowedContentTypes: [UTType.pdf],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let files):
                        guard let fileURL = files.first else {
                            print("OrderCreationView: No file URL received from picker.")
                            return
                        }
                        
                        print("OrderCreationView: PDF selected: \(fileURL.lastPathComponent)")
                        print("OrderCreationView: Attempting to load data from URL: \(fileURL)")
                        
                        // Ensure the app has permission to access the file URL
                        let accessing = fileURL.startAccessingSecurityScopedResource()
                        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }
                        
                        do {
                            let data = try Data(contentsOf: fileURL)
                            print("OrderCreationView: Successfully loaded PDF data: \(data.count) bytes")
                            
                            print("OrderCreationView: Calling viewModel.uploadAttachment")
                            viewModel.uploadAttachment(data, type: .pdf, name: fileURL.lastPathComponent) { result in
                                DispatchQueue.main.async { // Ensure UI updates on main thread
                                    switch result {
                                    case .success(let attachment):
                                        print("OrderCreationView: PDF upload successful, adding attachment.")
                                        viewModel.addAttachment(attachment)
                                    case .failure(let error):
                                        print("OrderCreationView: Error uploading PDF: \(error.localizedDescription)")
                                        // Optionally show an error to the user
                                        viewModel.errorMessage = "Failed to upload PDF: \(error.localizedDescription)"
                                        viewModel.showError = true
                                    }
                                }
                            }
                        } catch {
                            print("OrderCreationView: Error reading data from PDF URL \(fileURL): \(error.localizedDescription)")
                            viewModel.errorMessage = "Failed to read PDF file."
                            viewModel.showError = true
                        }
                        
                    case .failure(let error):
                        print("OrderCreationView: Error selecting PDF: \(error.localizedDescription)")
                        viewModel.errorMessage = "Failed to select PDF file."
                        viewModel.showError = true
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .local)
                    .updating($scrollVelocity) { value, state, _ in
                        let velocity = value.translation.height / max(1, value.time.timeIntervalSince(.now))
                        state = velocity
                        
                        if velocity > 50 {
                            UIApplication.shared.endEditing()
                        }
                    }
            )
            
            BackgroundLogo(opacity: 0.2)
        }
        
    }
    
    private var customerSection: some View {
        Section("Customer Details") {
            ChatParticipantSelectView(selectedParticipants: $selectedCustomers)
                .onChange(of: selectedCustomers) { newValue in
                    if let customerId = newValue.first {
                        viewModel.customerId = customerId
                        viewModel.fetchBrands(for: customerId)
                    }
                }
        }
        
    }
    
    private var brandSection: some View {
        Section("Brand") {
            if !viewModel.brands.isEmpty {
                if viewModel.brands.count == 1 {
                    let brand = viewModel.brands[0]
                    Text(brand.name)
                        .onAppear {
                            viewModel.selectedBrand = brand
                            viewModel.brandId = brand.id
                            viewModel.brandName = brand.name
                            print("Selected default brand: \(brand.name) with ID: \(brand.id)")
                        }
                } else {
                    Picker("Select Brand", selection: $viewModel.selectedBrand) {
                        ForEach(viewModel.brands) { brand in
                            Text(brand.name)
                                .tag(Optional(brand))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: viewModel.selectedBrand) { newValue in
                        if let brand = newValue {
                            viewModel.brandId = brand.id
                            viewModel.brandName = brand.name
                            print("Selected brand from picker: \(brand.name) with ID: \(brand.id)")
                        } else {
                            print("Brand selection was cleared")
                        }
                    }
                }
            } else {
                Text("Please select a customer first")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var orderItemsSection: some View {
        Section("Order Items") {
            ForEach(viewModel.items.filter { $0.productType != .tax && $0.productType != .discount }) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text("\(item.quantity)x")
                    Text("$\(String(format: "%.2f", item.price))")
                    Text(item.productType.rawValue.capitalized)
                }
            }
            
            Button("Add Item") {
                isAddItemPresented = true
            }
        }
    }
    
    private var attachmentsSection: some View {
        Section("Attachments") {
            ForEach(viewModel.attachments) { attachment in
                HStack {
                    Text(attachment.name)
                    Spacer()
                    Text(attachment.type.rawValue.capitalized)
                }
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    viewModel.removeAttachment(at: index)
                }
            }
            
            Button("Add Attachment") {
                isImagePickerPresented = true
            }
        }
    }
    
    private var taxSection: some View {
        Section("Tax") {
            TextField("Tax Amount", text: $taxAmount)
                .keyboardType(.decimalPad)
                // .addDoneButtonToKeyboard()
                .onChange(of: taxAmount) { newValue in
                    if let tax = Double(newValue) {
                        viewModel.items.removeAll { $0.name == "Tax" }
                        let taxItem = OrderItem(
                            id: UUID().uuidString,
                            name: "Tax",
                            quantity: 1,
                            price: tax,
                            productType: .tax
                        )
                        viewModel.items.append(taxItem)
                    }
                }
        }
    }
    
    private var discountSection: some View {
        Section("Discount") {
            TextField("Discount Amount", text: $discountAmount)
                .keyboardType(.decimalPad)
                // .addDoneButtonToKeyboard()
                .onChange(of: discountAmount) { newValue in
                    if let discount = Double(newValue) {
                        viewModel.items.removeAll { $0.name == "Discount" }
                        let discountItem = OrderItem(
                            id: UUID().uuidString,
                            name: "Discount",
                            quantity: 1,
                            price: -discount,
                            productType: .discount
                        )
                        viewModel.items.append(discountItem)
                    }
                }
        }
    }
    
    private var summarySection: some View {
        Section("Order Summary") {
            Text("Total Amount: $\(String(format: "%.2f", viewModel.totalAmount))")
        }
    }
    
    private var leadingToolbarItems: some View {
        Button("Clear") {
            selectedCustomers = []
            viewModel.customerId = ""
            viewModel.brandId = ""
            viewModel.brandName = ""
            viewModel.selectedBrand = nil
            viewModel.items = []
            viewModel.attachments = []
            taxAmount = ""
            discountAmount = ""
            dismiss()
        }
    }
    
    private var trailingToolbarItems: some View {
        Button("Create") {
            if viewModel.createOrder() != nil {
                // Clear all inputs after successful order creation
                
                showSuccessAlert = true
            }
        }
        .disabled(!viewModel.isValid)
    }
    
    private var attachmentPickerSheet: some View {
        NavigationView {
            VStack {
                Picker("Attachment Type", selection: $selectedAttachmentType) {
                    Text("Image").tag(OrderAttachment.AttachmentType.image)
                    Text("Document").tag(OrderAttachment.AttachmentType.pdf)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedAttachmentType == .image {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images
                    ) {
                        Label("Select Image", systemImage: "photo")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                viewModel.uploadAttachment(data, type: .image, name: "Image \(viewModel.attachments.count + 1)") { result in
                                    switch result {
                                    case .success(let attachment):
                                        viewModel.addAttachment(attachment)
                                        isImagePickerPresented = false
                                    case .failure(let error):
                                        print("Error uploading image: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Button {
                        showDocumentPicker = true
                        isImagePickerPresented = false
                    } label: {
                        Label("Select PDF", systemImage: "doc")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Add Attachment")
            .navigationBarItems(trailing: Button("Cancel") {
                isImagePickerPresented = false
            })
        }
    }
}

struct OrderCreationView_Previews: PreviewProvider {
    static var previews: some View {
        OrderCreationView()
    }
}