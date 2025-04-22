import SwiftUI
import FirebaseAuth

struct ChatMultiCreationView: View {
    @StateObject private var viewModel = ChatMultiCreationViewModel()
    @State private var selectedCustomers = Set<String>()
    @State private var printTeamParticipants = Set<String>()
    @State private var designTeamParticipants = Set<String>()
    @State private var fileSetupParticipants = Set<String>()
    @State private var customerSearchText = ""
    @State private var printTeamSearchText = ""
    @State private var designTeamSearchText = ""
    @State private var fileSetupSearchText = ""
    @Environment(\.dismiss) private var dismiss
    
    var filteredCustomers: [User] {
        let availableCustomers = viewModel.currentUserRole == .accountManager ? 
            viewModel.customers.filter { viewModel.currentUserCustomerIds.contains($0.email) } :
            viewModel.customers
            
        let selectedUsers = availableCustomers.filter { selectedCustomers.contains($0.email) }
        
        if customerSearchText.isEmpty {
            return selectedUsers.sorted { $0.name < $1.name }
        }
        
        let filtered = availableCustomers.filter { user in
            user.name.localizedCaseInsensitiveContains(customerSearchText)
        }
        return Array(Set(filtered + selectedUsers)).sorted { $0.name < $1.name }
    }
    
    var filteredPrintTeam: [User] {
        let selectedUsers = viewModel.nonCustomerUsers.filter { printTeamParticipants.contains($0.email) }
        if printTeamSearchText.isEmpty {
            return selectedUsers.sorted { $0.name < $1.name }
        }
        let filtered = viewModel.nonCustomerUsers.filter { user in
            user.name.localizedCaseInsensitiveContains(printTeamSearchText)
        }
        return Array(Set(filtered + selectedUsers)).sorted { $0.name < $1.name }
    }
    
    var filteredDesignTeam: [User] {
        let selectedUsers = viewModel.nonCustomerUsers.filter { designTeamParticipants.contains($0.email) }
        if designTeamSearchText.isEmpty {
            return selectedUsers.sorted { $0.name < $1.name }
        }
        let filtered = viewModel.nonCustomerUsers.filter { user in
            user.name.localizedCaseInsensitiveContains(designTeamSearchText)
        }
        return Array(Set(filtered + selectedUsers)).sorted { $0.name < $1.name }
    }
    
    var filteredFileSetupTeam: [User] {
        let selectedUsers = viewModel.nonCustomerUsers.filter { fileSetupParticipants.contains($0.email) }
        if fileSetupSearchText.isEmpty {
            return selectedUsers.sorted { $0.name < $1.name }
        }
        let filtered = viewModel.nonCustomerUsers.filter { user in
            user.name.localizedCaseInsensitiveContains(fileSetupSearchText)
        }
        return Array(Set(filtered + selectedUsers)).sorted { $0.name < $1.name }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        ScrollViewReader { scrollProxy in
                            VStack(alignment: .leading, spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("Select Customers")
                                        .font(.headline)
                                    TextField("Search customers by name...", text: $customerSearchText)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .padding(.bottom, 8)
                                    SearchableUserSection(
                                        title: "",
                                        items: filteredCustomers,
                                        selectedEmails: $selectedCustomers,
                                        searchText: $customerSearchText
                                    )
                                }

                                Divider()
                                    .padding(.vertical, 8)
                                
                                VStack(alignment: .leading) {
                                    Text("Print Team Members")
                                        .font(.headline)
                                    TextField("Search print team by name...", text: $printTeamSearchText)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .padding(.bottom, 8)
                                    SearchableUserSection(
                                        title: "",
                                        items: filteredPrintTeam,
                                        selectedEmails: $printTeamParticipants,
                                        searchText: $printTeamSearchText
                                    )
                                }

                                Divider()
                                    .padding(.vertical, 8)
                                
                                VStack(alignment: .leading) {
                                    Text("Design Team Members")
                                        .font(.headline)
                                    TextField("Search design team by name...", text: $designTeamSearchText)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .padding(.bottom, 8)
                                    SearchableUserSection(
                                        title: "",
                                        items: filteredDesignTeam,
                                        selectedEmails: $designTeamParticipants,
                                        searchText: $designTeamSearchText
                                    )
                                }

                                Divider()
                                    .padding(.vertical, 8)
                                
                                VStack(alignment: .leading) {
                                    Text("File Setup Team Members")
                                        .font(.headline)
                                    TextField("Search file setup by name...", text: $fileSetupSearchText)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .padding(.bottom, 8)
                                        .onChange(of: fileSetupSearchText) { newValue in
                                            if !newValue.isEmpty {
                                                withAnimation {
                                                    scrollProxy.scrollTo("fileSetupResults", anchor: .top)
                                                }
                                            }
                                        }
                                    SearchableUserSection(
                                        title: "",
                                        items: filteredFileSetupTeam,
                                        selectedEmails: $fileSetupParticipants,
                                        searchText: $fileSetupSearchText
                                    )
                                    .id("fileSetupResults")
                                }
                            }
                            .padding()
                            .padding(.bottom, 100)
                        }
                        .addDoneButtonToKeyboard()
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
                                try await viewModel.createProjectChats(
                                    selectedCustomers: selectedCustomers,
                                    printTeamParticipants: printTeamParticipants,
                                    designTeamParticipants: designTeamParticipants,
                                    fileSetupParticipants: fileSetupParticipants
                                )
                                dismiss()
                            } catch {
                                print("Error creating project chats: \(error.localizedDescription)")
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

struct SearchableUserSection: View {
    let title: String
    let items: [User]
    @Binding var selectedEmails: Set<String>
    @Binding var searchText: String
    
    var body: some View {
        VStack(alignment: .leading) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            
            ForEach(items) { user in
                HStack {
                    Text(user.name)
                    Spacer()
                    if selectedEmails.contains(user.email) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedEmails.contains(user.email) {
                        selectedEmails.remove(user.email)
                    } else {
                        selectedEmails.insert(user.email)
                    }
                    searchText = ""
                }
                .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    ChatMultiCreationView()
}
