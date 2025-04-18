import SwiftUI

struct OrderEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel: OrderEditViewModel

    init(order: Order, onSave: @escaping (OrderStatus, [OrderItem]) -> Void) {
        _viewModel = StateObject(wrappedValue: OrderEditViewModel(order: order))
        self.onSave = onSave
    }

    var onSave: (OrderStatus, [OrderItem]) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Order Status") {
                    Picker("Status", selection: $viewModel.status) {
                        ForEach(OrderStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized == "Inprogress" ? "In Progress" : status.rawValue.capitalized).tag(status)
                        }
                    }
                }
                
                Section("Items") {
                    ForEach($viewModel.items) { $item in
                        VStack(alignment: .leading) {
                            TextField("Item Name", text: $item.name)
                            HStack {
                                TextField("Quantity", value: $item.quantity, formatter: NumberFormatter())
                                    .keyboardType(.numberPad)
                                    // .addDoneButtonToKeyboard()
                                TextField("Price", value: $item.price, formatter: NumberFormatter())
                                    .keyboardType(.decimalPad)
                                    .addDoneButtonToKeyboard()
                                Picker("", selection: $item.productType) {
                                    ForEach(ProductType.allCases, id: \.self) { type in
                                        Text(type.rawValue.capitalized).tag(type)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        viewModel.items.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Item") {
                        // Logic to add a new item
                    }
                }
                
                Section {
                    HStack {
                        Text("Total Amount")
                        Spacer()
                        Text("$\(String(format: "%.2f", viewModel.totalAmount))")
                            .bold()
                    }
                }
            }
            .navigationTitle("Edit Order")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveChanges { updatedStatus, updatedItems in
                            onSave(updatedStatus, updatedItems)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .alert(item: $viewModel.errorMessage) { error in
                Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
            }
        }
    }
}