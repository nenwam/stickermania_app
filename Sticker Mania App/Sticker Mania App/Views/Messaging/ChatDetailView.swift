import SwiftUI
import PhotosUI

struct ChatDetailView: View {
    let chatId: String
    @StateObject private var viewModel = ChatDetailViewModel()
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var showingParticipants = false
    @State private var selectedMedia: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var enlargedImage: IdentifiableURL?
    @State private var showingDocumentPicker = false
    @State private var showingPhotoPicker = false // New state variable

    private let messagesPerPage = 20

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
                            if let mediaUrl = message.mediaUrl {
                                if message.mediaType == .image {
                                    Button(action: {
                                        if let url = URL(string: mediaUrl) {
                                            enlargedImage = IdentifiableURL(url: url)
                                        }
                                    }) {
                                        AsyncImage(url: URL(string: mediaUrl)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(maxWidth: 200)
                                                    .cornerRadius(8)
                                            case .failure:
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    }
                                } else if message.mediaType == .video {
                                    Link(destination: URL(string: mediaUrl)!) {
                                        VStack {
                                            if let url = URL(string: mediaUrl) {
                                                VideoThumbnailView(videoURL: url)
                                                    .frame(width: 200, height: 150)
                                                    .cornerRadius(8)
                                            }
                                            Text("View Video")
                                                .font(.caption)
                                        }
                                        .frame(maxWidth: 200)
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                } else if message.mediaType == .pdf {
                                    Link(destination: URL(string: mediaUrl)!) {
                                        VStack {
                                            Image(systemName: "doc.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 60, height: 60)
                                                .foregroundColor(.red)
                                            Text("View PDF")
                                                .font(.caption)
                                        }
                                        .frame(maxWidth: 200)
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            if (message.mediaType != .image && message.mediaType != .video && message.mediaType != .pdf) {
                                MessageBubble(message: message, participants: viewModel.participants)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) { _ in
                    if !viewModel.isLoadingMore {
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
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
        .sheet(item: $enlargedImage) { identifiableURL in
            EnlargedImageView(imageUrl: identifiableURL.url)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedMedia, matching: .any(of: [.images, .videos]))
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            Task {
                do {
                    let fileUrl = try result.get().first!
                    let data = try Data(contentsOf: fileUrl)
                    isLoading = true
                    await viewModel.sendPDF(data, chatId: chatId)
                    isLoading = false
                } catch {
                    print("Error loading PDF: \(error.localizedDescription)")
                }
            }
        }
        .onChange(of: selectedMedia) { item in
            guard let item = item else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        if let typeIdentifier = item.supportedContentTypes.first {
                            print("Type identifier: \(typeIdentifier)")
                            if typeIdentifier.conforms(to: .movie) {
                                print("Video data loaded successfully")
                                isLoading = true
                                await viewModel.sendVideo(data, chatId: chatId)
                                isLoading = false
                            } else if typeIdentifier.conforms(to: .image) {
                                print("Image data loaded successfully")
                                isLoading = true
                                await viewModel.sendImage(data, chatId: chatId)
                                isLoading = false
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
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
}

#Preview {
    NavigationView {
        ChatDetailView(chatId: "previewChat")
    }
}