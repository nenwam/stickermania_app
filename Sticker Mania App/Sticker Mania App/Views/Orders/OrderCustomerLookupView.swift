import SwiftUI

struct OrderCustomerLookupView: View {
    @State private var selectedCustomers: [String] = []
    @State private var shouldNavigate = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Look Up Customer Orders")
                    .font(.title)
                    .padding(.top)
                
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
