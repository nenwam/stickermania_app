import SwiftUI
import PhotosUI
import QuickLook

struct OrderDetailView: View {
    @StateObject private var viewModel: OrderDetailViewModel
    @State private var showEditView = false
    @State private var previewItemURL: URL?
    @State private var loadingAttachmentId: String? = nil // State to track loading attachment
    @State private var showDeleteConfirmation = false
    @Environment(\.presentationMode) var presentationMode

    init(order: Order) {
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(order: order))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    loadingView
                } else {
                    orderHeaderView
                    orderDetailsView
                    orderItemsView
                    attachmentsView
                    orderActionsView
                }
                
                errorView
            }
            .padding()
        }
        .navigationTitle("Order Details")
        .onAppear {
            viewModel.refreshOrderDetails()
        }
        .quickLookPreview($previewItemURL, in: previewItemURL.map { [$0] } ?? [])
        .alert("Delete Order", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                // Do nothing, just dismiss the alert
            }
            Button("Delete", role: .destructive) {
                viewModel.deleteOrder { success in
                    if success {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this order? This action cannot be undone.")
        }
    }
    
    private var loadingView: some View {
        ProgressView("Loading...")
            .padding()
    }
    
    private var orderHeaderView: some View {
        VStack {
            HStack {
                Spacer()
                if viewModel.canDeleteOrder {
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Order")
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            HStack {
                Text("Order #\(viewModel.order.id)")
                    .font(.title2)
                    .bold()
                Spacer()
                Text(viewModel.order.status == .inProgress ? "In Progress" : viewModel.order.status.rawValue.capitalized)
                    .font(.headline)
            }
        }
        .padding(.bottom)
    }
    
    private var orderDetailsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Order Details")
                .font(.headline)
            
            Text("Customer Email: \(viewModel.order.customerEmail)")
            Text("Brand Name: \(viewModel.order.brandName)")
            Text("Date: \(viewModel.order.createdAt, style: .date)")
            Text("Total Amount: $\(String(format: "%.2f", viewModel.order.totalAmount))")
        }
    }
    
    private var orderItemsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Items")
                .font(.headline)
            
            let regularItems = viewModel.order.items.filter { $0.productType != .tax && $0.productType != .discount }
            let taxItems = viewModel.order.items.filter { $0.productType == .tax }
            let discountItems = viewModel.order.items.filter { $0.productType == .discount }
            
            ForEach(regularItems, id: \.id) { item in
                itemRow(item)
            }
            
            ForEach(taxItems, id: \.id) { item in
                itemRow(item)
            }
            
            ForEach(discountItems, id: \.id) { item in
                itemRow(item)
            }
        }
    }
    
    private func itemRow(_ item: OrderItem) -> some View {
        HStack {
            Text(item.name)
            Spacer()
            Text("\(item.quantity)x")
            Text("$\(String(format: "%.2f", item.price))")
            Text(item.productType.rawValue.capitalized)
        }
    }
    
    private var attachmentsView: some View {
        Group {
            if !viewModel.order.attachments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attachments")
                        .font(.headline)
                    
                    ForEach(viewModel.order.attachments) { attachment in
                        attachmentRow(attachment)
                    }
                }
            }
        }
    }
    
    private func attachmentRow(_ attachment: OrderAttachment) -> some View {
        Button(action: {
            guard loadingAttachmentId == nil else { // Prevent starting new download if one is in progress
                print("OrderDetailView: Download already in progress for \(loadingAttachmentId ?? "?")")
                return
            }
            guard let remoteURL = URL(string: attachment.url) else {
                print("OrderDetailView: Invalid attachment URL: \(attachment.url)")
                return
            }

            Task {
                // Set loading state at the beginning
                loadingAttachmentId = attachment.id
                
                // Ensure loading state is cleared when the task finishes
                defer { loadingAttachmentId = nil }
                
                do {
                    print("OrderDetailView: Downloading attachment: \(attachment.name) from \(remoteURL)")
                    let (data, response) = try await URLSession.shared.data(from: remoteURL)
                    
                    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                        print("OrderDetailView: Download failed with status code \(httpResponse.statusCode)")
                        return
                    }
                    print("OrderDetailView: Downloaded data size: \(data.count) bytes")
                    
                    let fileExtension: String
                    switch attachment.type {
                    case .image: fileExtension = "jpg"
                    case .pdf: fileExtension = "pdf"
                    default: fileExtension = ""
                    }
                    
                    let tempDir = FileManager.default.temporaryDirectory
                    let uniqueBaseName = UUID().uuidString
                    let tempFileURL = tempDir.appendingPathComponent(uniqueBaseName).appendingPathExtension(fileExtension)
                    
                    print("OrderDetailView: Saving attachment to temporary file: \(tempFileURL.path)")
                    try data.write(to: tempFileURL)
                    
                    previewItemURL = tempFileURL
                    print("OrderDetailView: Set previewItemURL to: \(tempFileURL)")
                    
                } catch {
                    print("OrderDetailView: Error processing attachment \(attachment.name): \(error)")
                }
            }
        }) {
            HStack {
                Image(systemName: attachment.type == .image ? "photo" : "doc.fill")
                    .foregroundColor(attachment.type == .pdf ? .red : .primary)
                Text(attachment.name)
                
                // Conditionally show ProgressView
                if loadingAttachmentId == attachment.id {
                    ProgressView()
                        .padding(.leading, 4)
                }
                
                Spacer()
                Text(attachment.type.rawValue.capitalized == "Image" ? "Image" : "PDF")
            }
        }
        .disabled(loadingAttachmentId != nil) // Optionally disable the button while any attachment is loading
    }
    
    private var orderActionsView: some View {
        VStack {
            if !viewModel.isCustomer {
                Button("Edit Order Details") {
                    showEditView = true
                }
                .sheet(isPresented: $showEditView) {
                    OrderEditView(order: viewModel.order) { updatedStatus, updatedItems in
                        viewModel.updateOrder(withStatus: updatedStatus, items: updatedItems)
                    }
                }
            }
        }
    }
    
    private var errorView: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
}