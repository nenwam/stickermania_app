import SwiftUI

struct OrderDetailView: View {
    @StateObject private var viewModel: OrderDetailViewModel
    @State private var showEditView = false

    init(order: Order) {
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(order: order))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .padding()
                } else {
                    // Order Header
                    HStack {
                        Text("Order #\(viewModel.order.id)")
                            .font(.title2)
                            .bold()
                        Spacer()
                        Text(viewModel.order.status == .inProgress ? "In Progress" : viewModel.order.status.rawValue)
                            .font(.headline)
                    }
                    .padding(.bottom)
                    
                    // Order Details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Order Details")
                            .font(.headline)
                        
                        Text("Customer ID: \(viewModel.order.customerId)")
                        Text("Brand Name: \(viewModel.order.brandName)")
                        Text("Date: \(viewModel.order.createdAt, style: .date)")
                        Text("Total Amount: $\(String(format: "%.2f", viewModel.order.totalAmount))")
                    }
                    
                    // Items List
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Items")
                            .font(.headline)
                        
                        ForEach(viewModel.order.items.filter { $0.productType != .tax && $0.productType != .discount }, id: \.id) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("\(item.quantity)x")
                                Text("$\(String(format: "%.2f", item.price))")
                                Text(item.productType.rawValue.capitalized)
                            }
                        }
                        
                        ForEach(viewModel.order.items.filter { $0.productType == .tax }, id: \.id) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("\(item.quantity)x")
                                Text("$\(String(format: "%.2f", item.price))")
                                Text(item.productType.rawValue.capitalized)
                            }
                        }
                        
                        ForEach(viewModel.order.items.filter { $0.productType == .discount }, id: \.id) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("\(item.quantity)x")
                                Text("$\(String(format: "%.2f", item.price))")
                                Text(item.productType.rawValue.capitalized)
                            }
                        }
                    }
                    
                    // Edit Order Button
                    Button("Edit Order Details") {
                        showEditView = true
                    }
                    .sheet(isPresented: $showEditView) {
                        OrderEditView(order: viewModel.order) { updatedStatus, updatedItems in
                            viewModel.updateOrder(withStatus: updatedStatus, items: updatedItems)
                        }
                    }
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Order Details")
        .onAppear {
            viewModel.refreshOrderDetails()
        }
    }
}