import SwiftUI
import PhotosUI
import FirebaseAuth
import UniformTypeIdentifiers

struct ChatDetailView: View {
    let chatId: String
    @StateObject private var viewModel = ChatDetailViewModel()
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var showingParticipants = false
    @State private var selectedMedia: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showingDocumentPicker = false
    @State private var showingPhotoPicker = false
    @State private var messageParticipants: [User] = []
    @GestureState private var scrollVelocity: CGFloat = 0
    @Environment(\.presentationMode) private var presentationMode
    
    // Add state for QuickLook
    @State private var previewItemURL: URL? = nil
    @State private var loadingMediaId: String? = nil
    @State private var isUploadingMedia = false // State to track media uploads

    private let messagesPerPage = 10
    

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.hasMoreMessages {
                            Button(action: {
                                Task {
                                    await viewModel.loadMoreMessages(chatId: chatId)
                                }
                            }) {
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                } else {
                                    Text("Load More")
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        ForEach(viewModel.messages) { message in
                            if let mediaUrl = message.mediaUrl, message.mediaType != nil, message.mediaType != .text {
                                MessageMedia(message: message, 
                                             participants: viewModel.participants, 
                                             mediaType: message.mediaType!, 
                                             loadingMediaId: $loadingMediaId, 
                                             previewItemURL: $previewItemURL)
                                    .id(message.id)
                            } else if message.text != nil && !message.text!.isEmpty {
                                MessageBubble(message: message, participants: viewModel.participants)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.loadMoreMessages(chatId: chatId)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5, coordinateSpace: .local)
                        .updating($scrollVelocity) { value, state, _ in
                            let velocity = value.translation.height / max(1, value.time.timeIntervalSince(.now))
                            state = velocity
                            
                            if velocity > 50 {
                                UIApplication.shared.endEditing()
                            }
                        }
                )
                .onChange(of: viewModel.messages) { _ in
                    if !viewModel.isLoadingMore && !viewModel.loadedOlderMessages {
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                    
                    if viewModel.loadedOlderMessages && !viewModel.isLoadingMore {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            viewModel.loadedOlderMessages = false
                        }
                    }
                }
            }

            HStack {
                Menu {
                    Button(action: { showingPhotoPicker = true }) {
                        Label("Photo/Video", systemImage: "photo")
                    }
                    Button(action: { showingDocumentPicker = true }) {
                        Label("PDF Document", systemImage: "doc.fill")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .imageScale(.large)
                }
                .disabled(isLoading)

                TextField("Message", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)
                    .dismissKeyboardOnSwipeDown()
                Button(action: {
                    Task {
                        isLoading = true
                        await viewModel.sendMessage(messageText, chatId: chatId)
                        messageText = ""
                        isLoading = false
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(messageText.isEmpty || isLoading)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: {
                    showingParticipants = true
                }) {
                    Image(systemName: "person.2")
                        .imageScale(.large)
                }
            }
        }
        .sheet(isPresented: $showingParticipants) {
            ChatParticipantsView(participants: viewModel.participants, chatType: viewModel.chatType)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedMedia, matching: .any(of: [.images, .videos]))
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            Task {
                // Set uploading state
                isUploadingMedia = true
                // Ensure state is reset on exit
                defer { isUploadingMedia = false }
                
                do {
                    guard let fileUrl = try result.get().first else {
                        print("No file URL received from picker.")
                        return
                    }
                    print("PDF selected: \(fileUrl.lastPathComponent)")
                    print("Attempting to load data from URL: \(fileUrl)")
                    
                    // Ensure the app has permission to access the file URL
                    let accessing = fileUrl.startAccessingSecurityScopedResource()
                    defer { if accessing { fileUrl.stopAccessingSecurityScopedResource() } }
                    
                    let data = try Data(contentsOf: fileUrl)
                    print("Successfully loaded PDF data: \(data.count) bytes")
                    
                    // isLoading = true // Use isUploadingMedia instead
                    print("Calling viewModel.sendPDF")
                    await viewModel.sendPDF(data, chatId: chatId)
                    print("viewModel.sendPDF finished")
                    // isLoading = false // Use isUploadingMedia instead
                    
                } catch {
                    print("Error processing selected PDF: \(error.localizedDescription)")
                    // Potentially display an error message to the user here
                    // isLoading = false // Use isUploadingMedia instead
                }
            }
        }
        .onChange(of: selectedMedia) { item in
            guard let item = item else { return }
            Task {
                // Set uploading state
                isUploadingMedia = true
                // Ensure state is reset on exit
                defer { isUploadingMedia = false }
                
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        if let typeIdentifier = item.supportedContentTypes.first {
                            print("Type identifier: \(typeIdentifier)")
                            if typeIdentifier.conforms(to: .movie) {
                                print("Video data loaded successfully")
                                // isLoading = true // Use isUploadingMedia instead
                                await viewModel.sendVideo(data, chatId: chatId)
                                // isLoading = false // Use isUploadingMedia instead
                            } else if typeIdentifier.conforms(to: .image) {
                                print("Image data loaded successfully")
                                // isLoading = true // Use isUploadingMedia instead
                                await viewModel.sendImage(data, chatId: chatId)
                                // isLoading = false // Use isUploadingMedia instead
                            }
                        }
                    } else {
                        print("Failed to load media data")
                    }
                } catch {
                    print("Error loading media data: \(error.localizedDescription)")
                }
            }
        }
        .onAppear {
            viewModel.startListening(chatId: chatId)
            Task {
                await viewModel.updateUnreadStatus(chatId: chatId)
            }
            print("Participants in viewModel: \(viewModel.participants.map { $0.email })")
        }
        .onDisappear {
            viewModel.stopListening()
            
            // Reset the active navigation in ChatListView when this view disappears
            NotificationCenter.default.post(
                name: Notification.Name("ResetChatNavigation"),
                object: nil
            )
            print("ChatDetailView: Posted ResetChatNavigation notification")
        }
        .quickLookPreview($previewItemURL, in: previewItemURL.map { [$0] } ?? [])
    }
}

#Preview {
    NavigationView {
        ChatDetailView(chatId: "previewChat")
    }
}