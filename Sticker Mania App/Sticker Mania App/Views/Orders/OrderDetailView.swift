import SwiftUI
import PhotosUI
import QuickLook

struct OrderDetailView: View {
    @StateObject private var viewModel: OrderDetailViewModel
    @State private var showEditView = false
    @State private var selectedImage: OrderAttachment?
    @State private var enlargedImage: IdentifiableURL?
    @State private var selectedPDF: URL?
    @State private var showingPDF = false
    @State private var pdfData: Data? // Added to store PDF data

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
                    editButtonView
                }
                
                errorView
            }
            .padding()
        }
        .navigationTitle("Order Details")
        .onAppear {
            viewModel.refreshOrderDetails()
        }
        .quickLookPreview($selectedPDF, in: selectedPDF.map { [$0] } ?? [])
    }
    
    private var loadingView: some View {
        ProgressView("Loading...")
            .padding()
    }
    
    private var orderHeaderView: some View {
        HStack {
            Text("Order #\(viewModel.order.id)")
                .font(.title2)
                .bold()
            Spacer()
            Text(viewModel.order.status == .inProgress ? "In Progress" : viewModel.order.status.rawValue)
                .font(.headline)
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
                .sheet(item: $enlargedImage) { identifiableURL in
                    EnlargedImageView(imageUrl: identifiableURL.url)
                }
            }
        }
    }
    
    private func attachmentRow(_ attachment: OrderAttachment) -> some View {
        Button(action: {
            if attachment.type == .image {
                if let url = URL(string: attachment.url) {
                    enlargedImage = IdentifiableURL(url: url)
                }
            } else if attachment.type == .pdf {
                if let url = URL(string: attachment.url) {
                    Task {
                        do {
                            // Download PDF data
                            let (data, _) = try await URLSession.shared.data(from: url)
                            
                            // Create temporary file
                            let tempDir = FileManager.default.temporaryDirectory
                            let tempFile = tempDir.appendingPathComponent(attachment.name)
                            try data.write(to: tempFile)
                            
                            // Store data and show preview
                            pdfData = data
                            selectedPDF = tempFile
                            showingPDF = true
                        } catch {
                            print("Error loading PDF: \(error)")
                        }
                    }
                }
            }
        }) {
            HStack {
                Image(systemName: attachment.type == .image ? "photo" : "doc.fill")
                    .foregroundColor(attachment.type == .pdf ? .red : .primary)
                Text(attachment.name)
                Spacer()
                Text(attachment.type.rawValue.capitalized)
            }
        }
    }
    
    private var editButtonView: some View {
        Group {
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