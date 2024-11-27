import SwiftUI
import FirebaseFirestore

struct ChatCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ChatCreationViewModel()
    @State private var selectedParticipants: [String] = []
    @State private var initialMessage: String = ""
    @State private var selectedChatType: ChatType = .team
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Chat Type")) {
                    Picker("Chat Type", selection: $selectedChatType) {
                        Text("Team").tag(ChatType.team)
                        Text("Customer").tag(ChatType.customer)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedChatType) { newValue in
                        print("Selected ChatType changed to: \(newValue.rawValue)")
                    }
                }
                
                Section(header: Text("Participants")) {
                    // TODO: Add participant selection UI
                    ChatParticipantSelectView(selectedParticipants: $selectedParticipants)
                }
                
                Section(header: Text("Initial Message")) {
                    TextField("Type your message...", text: $initialMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .navigationTitle("New Chat")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Create") {
                    viewModel.createChat(participants: selectedParticipants, initialMessage: initialMessage, chatType: selectedChatType)
                    dismiss()
                }
                .disabled(selectedParticipants.isEmpty || initialMessage.isEmpty)
            )
        }
    }
}

struct ChatCreationView_Previews: PreviewProvider {
    static var previews: some View {
        ChatCreationView()
    }
}
