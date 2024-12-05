import SwiftUI

struct OrderListView: View {
    @StateObject private var viewModel = OrderListViewModel()
    @State private var selectedStatus: OrderStatus?
    @State private var selectedDateFilter: DateFilter = .all
    @State private var selectedBrand: Brand?
    let customerId: String
    
    enum DateFilter {
        case all, lastWeek, lastMonth, last3Months
        
        var description: String {
            switch self {
            case .all: return "All Time"
            case .lastWeek: return "Last Week"
            case .lastMonth: return "Last Month" 
            case .last3Months: return "Last 3 Months"
            }
        }
        
        func filterDate(_ date: Date) -> Bool {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .all:
                return true
            case .lastWeek:
                let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
                return date >= weekAgo
            case .lastMonth:
                let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
                return date >= monthAgo
            case .last3Months:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)!
                return date >= threeMonthsAgo
            }
        }
    }

    var filteredOrders: [Order] {
        viewModel.orders.filter { order in
            let statusMatch = selectedStatus == nil || order.status == selectedStatus
            let dateMatch = selectedDateFilter.filterDate(order.createdAt)
            let brandMatch = selectedBrand == nil || order.brandId == selectedBrand?.id
            return statusMatch && dateMatch && brandMatch
        }
    }

    var body: some View {
        VStack {
            Text("Orders for \(viewModel.customerName ?? "Customer")")
                .font(.headline)
                .padding(.top)
            
            // Filter Controls
            VStack(spacing: 10) {
                Picker("Date Filter", selection: $selectedDateFilter) {
                    ForEach([DateFilter.all, .lastWeek, .lastMonth, .last3Months], id: \.self) { filter in
                        Text(filter.description).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Picker("Status Filter", selection: $selectedStatus) {
                        Text("All Status").tag(Optional<OrderStatus>.none)
                        ForEach(OrderStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(Optional(status))
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Brand Filter", selection: $selectedBrand) {
                        Text("All Brands").tag(Optional<Brand>.none)
                        ForEach(viewModel.brands, id: \.id) { brand in
                            Text(brand.name).tag(Optional(brand))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding()
            
            List {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else {
                    ForEach(filteredOrders, id: \.id) { order in
                        NavigationLink(destination: OrderDetailView(order: order)) {
                            OrderCell(order: order)
                        }
                    }
                }
            }
        }
        .navigationTitle("Orders")
        .onAppear {
            viewModel.fetchOrders(forCustomerId: customerId)
            viewModel.fetchBrands(forCustomerId: customerId)
        }
        .alert(item: $viewModel.errorMessage) { error in
            Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
    }
}

struct OrderListView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleOrders = [
            Order(
                id: "123",
                customerEmail: "customer1@email.com",
                accountManagerEmail: "manager1@email.com", 
                brandId: "brand1",
                brandName: "Brand 1",
                items: [
                    OrderItem(id: "item1", name: "Sticker Pack 1", quantity: 2, price: 9.99, productType: .qpBag),
                    OrderItem(id: "item2", name: "Custom Sticker", quantity: 1, price: 4.99, productType: .sticker)
                ],
                status: .pending,
                createdAt: Date(),
                totalAmount: 24.97,
                attachments: []
            ),
            Order(
                id: "456",
                customerEmail: "customer2@email.com",
                accountManagerEmail: "manager2@email.com",
                brandId: "brand2",
                brandName: "Brand 2",
                items: [
                    OrderItem(id: "item3", name: "Logo Stickers", quantity: 5, price: 3.99, productType: .sticker)
                ],
                status: .inProgress,
                createdAt: Date().addingTimeInterval(-86400), // Yesterday
                totalAmount: 19.95,
                attachments: []
            ),
            Order(
                id: "789",
                customerEmail: "customer3@email.com",
                accountManagerEmail: "manager1@email.com",
                brandId: "brand3",
                brandName: "Brand 3",
                items: [
                    OrderItem(id: "item4", name: "Holographic Pack", quantity: 1, price: 14.99, productType: .qpBag),
                    OrderItem(id: "item5", name: "Vinyl Stickers", quantity: 3, price: 7.99, productType: .sticker),
                    OrderItem(id: "item6", name: "Mini Stickers", quantity: 2, price: 4.99, productType: .sticker)
                ],
                status: .completed,
                createdAt: Date().addingTimeInterval(-172800), // 2 days ago
                totalAmount: 48.94,
                attachments: []
            )
        ]
        
        // OrderListView()
    }
}