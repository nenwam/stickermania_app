import SwiftUI

struct AddOrderItem: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var quantity: String = ""
    @State private var price: String = ""
    @State private var productType: ProductType = .sticker
    
    var onAdd: (OrderItem) -> Void
    
    private var isValid: Bool {
        !name.isEmpty && 
        !quantity.isEmpty && 
        !price.isEmpty &&
        Double(price) != nil &&
        Int(quantity) != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Item Name", text: $name)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                        .addDoneButtonToKeyboard()
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                        .addDoneButtonToKeyboard()
                    Picker("Product Type", selection: $productType) {
                        ForEach(ProductType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        guard let quantity = Int(quantity),
                              let price = Double(price) else {
                            return
                        }
                        
                        let item = OrderItem(
                            id: UUID().uuidString,
                            name: name,
                            quantity: quantity,
                            price: price,
                            productType: productType
                        )
                        
                        onAdd(item)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

struct AddOrderItem_Previews: PreviewProvider {
    static var previews: some View {
        AddOrderItem { _ in }
    }
}
