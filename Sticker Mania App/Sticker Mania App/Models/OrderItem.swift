struct OrderItem: Identifiable {
    let id: String
    var name: String
    var quantity: Int
    var price: Double
    var productType: ProductType
}

enum ProductType: String, CaseIterable {
    case bag = "bag"
    case qpBag = "qp-bag"
    case sticker = "sticker"
    case tax = "tax"
    case discount = "discount"

    var id: String { self.rawValue }
}