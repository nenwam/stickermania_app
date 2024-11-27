import SwiftUI
import FirebaseFirestore

struct OrderCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OrderCreationViewModel()
    @State private var isAddItemPresented = false
    @State private var showSuccessAlert = false
    @State private var selectedCustomers: [String] = []
    @State private var taxAmount: String = ""
    @State private var discountAmount: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Customer Details") {
                    ChatParticipantSelectView(selectedParticipants: $selectedCustomers)
                        .onChange(of: selectedCustomers) { newValue in
                            if let customerId = newValue.first {
                                viewModel.customerId = customerId
                                viewModel.fetchBrands(for: customerId)
                            }
                        }
                }
                
                Section("Brand") {
                    if !viewModel.brands.isEmpty {
                        Picker("Select Brand", selection: $viewModel.selectedBrand) {
                            ForEach(viewModel.brands) { brand in
                                Text(brand.name)
                                    .tag(brand)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: viewModel.selectedBrand) { newValue in
                            if let brand = newValue {
                                viewModel.brandId = brand.id
                                viewModel.brandName = brand.name
                            }
                        }
                    } else {
                        Text("Please select a customer first")
                            .foregroundColor(.gray)
                    }
                }
                
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
                
                Section("Tax") {
                    TextField("Tax Amount", text: $taxAmount)
                        .keyboardType(.decimalPad)
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
                
                Section("Discount") {
                    TextField("Discount Amount", text: $discountAmount)
                        .keyboardType(.decimalPad)
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
                
                Section("Order Summary") {
                    Text("Total Amount: $\(String(format: "%.2f", viewModel.totalAmount))")
                }
            }
            .navigationTitle("Create Order")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        selectedCustomers = []
                        viewModel.customerId = ""
                        viewModel.items = []
                        taxAmount = ""
                        discountAmount = ""
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        if viewModel.createOrder() != nil {
                            showSuccessAlert = true
                        }
                    }
                    .disabled(!viewModel.isValid)
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
        }
    }
    
    
}

struct OrderCreationView_Previews: PreviewProvider {
    static var previews: some View {
        OrderCreationView()
    }
}