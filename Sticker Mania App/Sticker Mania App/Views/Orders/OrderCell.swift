import SwiftUI

struct OrderCell: View {
    let order: Order
    
    private var backgroundColor: Color {
        switch order.status {
        case .pending:
            return Color(.systemYellow).opacity(0.15)
        case .inProgress:
            return Color(.systemBlue).opacity(0.15)
        case .flagged:
            return Color(.systemRed).opacity(0.15)
        case .completed:
            return Color(.systemGreen).opacity(0.15)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Order #\(order.id)")
                    .font(.headline)
                Spacer()
                Text(order.status == .inProgress ? "In Progress" : order.status.rawValue.capitalized)
                    .font(.subheadline)
            }
            
            Text("Total: $\(String(format: "%.2f", order.totalAmount))")
                .font(.subheadline)
            
            Text("Items: \(order.items.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(order.createdAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct OrderCell_Previews: PreviewProvider {
    static var previews: some View {
        OrderCell(order: Order(
            id: "123",
            customerEmail: "customer@example.com",
            customerUid: "uid123",
            accountManagerEmail: "manager@example.com", 
            brandId: "brand1",
            brandName: "Brand 1",
            items: [
                OrderItem(id: "item1", name: "Sticker Pack 1", quantity: 2, price: 9.99, productType: .sticker)
            ],
            status: .pending,
            createdAt: Date(),
            totalAmount: 19.98,
            attachments: []
        ))
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
