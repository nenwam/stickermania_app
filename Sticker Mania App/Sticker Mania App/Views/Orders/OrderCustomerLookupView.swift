import SwiftUI

struct OrderCustomerLookupView: View {
    enum SearchType {
        case orders, users
    }
    
    @State private var selectedCustomers: [String] = []
    @State private var shouldNavigate = false
    @State private var searchType: SearchType = .orders
    @State private var searchText = ""
    @State private var searchResults: [String] = [] // Would store user names/IDs
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Customer Lookup")
                    .font(.title)
                    .padding(.top)
                
                Picker("Search Type", selection: $searchType) {
                    Text("Orders").tag(SearchType.orders)
                    Text("Users").tag(SearchType.users)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if searchType == .orders {
                    ChatParticipantSelectView(selectedParticipants: $selectedCustomers)
                        .frame(height: 300)
                    
                    NavigationLink(
                        destination: OrderListView(customerId: selectedCustomers.first ?? ""),
                        isActive: $shouldNavigate
                    ) {
                        EmptyView()
                    }
                    
                    Button(action: {
                        if !selectedCustomers.isEmpty {
                            shouldNavigate = true
                        }
                    }) {
                        Text("Search Orders")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(selectedCustomers.isEmpty)
                    .padding(.horizontal)
                } else {
                    UserSearchView()
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct OrderCustomerLookupView_Previews: PreviewProvider {
    static var previews: some View {
        OrderCustomerLookupView()
    }
}
