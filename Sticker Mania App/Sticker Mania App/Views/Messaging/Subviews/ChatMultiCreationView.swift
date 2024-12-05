import SwiftUI

struct ChatMultiCreationView: View {
    @StateObject private var viewModel = ChatMultiCreationViewModel()
    @State private var selectedCustomers = Set<String>()
    @State private var printTeamParticipants = Set<String>()
    @State private var designTeamParticipants = Set<String>()
    @State private var customerSearchText = ""
    @State private var printTeamSearchText = ""
    @State private var designTeamSearchText = ""
    @Environment(\.dismiss) private var dismiss
    
    var filteredCustomers: [String] {
        if customerSearchText.isEmpty {
            return Array(selectedCustomers).sorted()
        }
        let filtered = viewModel.customers.filter { customer in
            customer.localizedCaseInsensitiveContains(customerSearchText)
        }
        return Array(Set(filtered + Array(selectedCustomers))).sorted()
    }
    
    var filteredPrintTeam: [String] {
        if printTeamSearchText.isEmpty {
            return Array(printTeamParticipants).sorted()
        }
        let filtered = viewModel.customers.filter { member in
            member.localizedCaseInsensitiveContains(printTeamSearchText)
        }
        return Array(Set(filtered + Array(printTeamParticipants))).sorted()
    }
    
    var filteredDesignTeam: [String] {
        if designTeamSearchText.isEmpty {
            return Array(designTeamParticipants).sorted()
        }
        let filtered = viewModel.customers.filter { member in
            member.localizedCaseInsensitiveContains(designTeamSearchText)
        }
        return Array(Set(filtered + Array(designTeamParticipants))).sorted()
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("Select Customers")
                                    .font(.headline)
                                TextField("Search customers...", text: $customerSearchText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.bottom, 8)
                                SearchableSection(
                                    title: "",
                                    items: filteredCustomers,
                                    selectedItems: $selectedCustomers
                                )
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Print Team Members")
                                    .font(.headline)
                                TextField("Search print team...", text: $printTeamSearchText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.bottom, 8)
                                SearchableSection(
                                    title: "",
                                    items: filteredPrintTeam,
                                    selectedItems: $printTeamParticipants
                                )
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Design Team Members")
                                    .font(.headline)
                                TextField("Search design team...", text: $designTeamSearchText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.bottom, 8)
                                SearchableSection(
                                    title: "",
                                    items: filteredDesignTeam,
                                    selectedItems: $designTeamParticipants
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Create Project Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            do {
                                // For each customer, create chats with them included in participants
                                for customer in selectedCustomers {
                                    var printTeamWithCustomer = printTeamParticipants
                                    printTeamWithCustomer.insert(customer)
                                    
                                    var designTeamWithCustomer = designTeamParticipants
                                    designTeamWithCustomer.insert(customer)
                                    
                                    try await viewModel.createProjectChats(
                                        selectedCustomers: [customer],
                                        printTeamParticipants: printTeamWithCustomer,
                                        designTeamParticipants: designTeamWithCustomer
                                    )
                                }
                                dismiss()
                            } catch {
                                // Handle error
                            }
                        }
                    }
                    .disabled(selectedCustomers.isEmpty)
                }
            }
        }
        .task {
            await viewModel.loadCustomers()
        }
    }
}

struct SearchableSection: View {
    let title: String
    let items: [String]
    @Binding var selectedItems: Set<String>
    
    var body: some View {
        VStack(alignment: .leading) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            
            ForEach(items, id: \.self) { item in
                HStack {
                    Text(item)
                    Spacer()
                    if selectedItems.contains(item) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedItems.contains(item) {
                        selectedItems.remove(item)
                    } else {
                        selectedItems.insert(item)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    ChatMultiCreationView()
}
