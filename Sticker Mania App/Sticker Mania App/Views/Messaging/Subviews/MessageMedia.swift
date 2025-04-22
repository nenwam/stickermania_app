//
//  MessageMedia.swift
//  Sticker Mania App
//
//  Created by Connor on 4/21/25.
//

import SwiftUI
import FirebaseAuth

struct MessageMedia: View {
    let message: ChatMessage
    let participants: [User]
    let mediaType: MediaType
    
    // Add bindings for QuickLook state
    @Binding var loadingMediaId: String?
    @Binding var previewItemURL: URL?
    
    private var senderName: String {
        if message.senderId == Auth.auth().currentUser?.email ?? "" {
            return "You"
        } else {
            if let participant = participants.first(where: { participant in
                let normalizedParticipantEmail = participant.email.trimmingCharacters(in: .whitespaces).lowercased()
                let normalizedSenderId = message.senderId.trimmingCharacters(in: .whitespaces).lowercased()
                return normalizedParticipantEmail == normalizedSenderId
            }) {
                return participant.name
            } else {
                return "Unknown User"
            }
        }
    }
    
    private var isCurrentUser: Bool {
        return message.senderId == Auth.auth().currentUser?.email ?? ""
    }
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Group {
                        if Calendar.current.isDateInToday(message.timestamp) {
                            Text(message.timestamp, style: .time)
                        } else {
                            Text(message.timestamp, style: .date) + Text(" ") + Text(message.timestamp, style: .time)
                        }
                    }
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    
                    if let mediaUrl = message.mediaUrl {
                        mediaContent(url: mediaUrl)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Group {
                        if Calendar.current.isDateInToday(message.timestamp) {
                            Text(message.timestamp, style: .time)
                        } else {
                            Text(message.timestamp, style: .date) + Text(" ") + Text(message.timestamp, style: .time)
                        }
                    }
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)

                    if let mediaUrl = message.mediaUrl {
                        mediaContent(url: mediaUrl)
                    }
                }
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func mediaContent(url: String) -> some View {
        // Wrap content in a Button to handle tap and download
        Button(action: {
            handleMediaTap(url: url)
        }) {
            HStack {
                // Existing media content display (Image, Video, PDF)
                mediaDisplayView(url: url)
                
                // Show ProgressView if this media is loading
                if loadingMediaId == message.id {
                    ProgressView()
                        .padding(.leading, 4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to avoid default button styling
        .disabled(loadingMediaId != nil) // Disable button while any media is loading
    }
    
    // Extracted view for displaying the media content itself
    @ViewBuilder
    private func mediaDisplayView(url: String) -> some View {
        if mediaType == .image {
            // Use thumbnailUrl if available, otherwise fall back to the main mediaUrl (passed as 'url' parameter)
            let displayURL = URL(string: message.thumbnailUrl ?? url)
            
            AsyncImage(url: displayURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: 200) // Maintain consistent frame size
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200)
                        .cornerRadius(8)
                case .failure:
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .frame(maxWidth: 200) // Maintain consistent frame size
                @unknown default:
                    EmptyView()
                }
            }
            .background(isCurrentUser ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(12)
        } else if mediaType == .video {
            VStack {
                // No Link here, handled by the Button
                // Safely unwrap the URL
                if let videoURL = URL(string: url) {
                    VideoThumbnailView(videoURL: videoURL)
                        .frame(width: 200, height: 150)
                        .cornerRadius(8)
                } else {
                    // Placeholder if URL is invalid
                    Image(systemName: "video.slash")
                        .frame(width: 200, height: 150)
                }
                Text("View Video")
                    .font(.caption)
            }
            .frame(maxWidth: 200)
            .padding()
            .background(isCurrentUser ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        } else if mediaType == .pdf {
            VStack {
                // No Link here, handled by the Button
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
            .background(isCurrentUser ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // Function to handle media tap, download, and preview setup
    private func handleMediaTap(url: String) {
        guard loadingMediaId == nil else {
            print("MessageMedia: Download already in progress for \(loadingMediaId ?? "?")")
            return
        }
        guard let remoteURL = URL(string: url) else {
            print("MessageMedia: Invalid media URL: \(url)")
            return
        }
        
        Task {
            loadingMediaId = message.id
            defer { loadingMediaId = nil }
            
            do {
                print("MessageMedia: Downloading media: \(message.id) from \(remoteURL)")
                let (data, response) = try await URLSession.shared.data(from: remoteURL)
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    print("MessageMedia: Download failed with status code \(httpResponse.statusCode)")
                    return
                }
                print("MessageMedia: Downloaded data size: \(data.count) bytes")
                
                let fileExtension: String
                switch mediaType {
                case .image: fileExtension = "jpg"
                case .video: fileExtension = "mp4" // Assuming mp4 for videos
                case .pdf: fileExtension = "pdf"
                case .text: fileExtension = "txt" // Should not happen for media
                }
                
                let tempDir = FileManager.default.temporaryDirectory
                let uniqueBaseName = UUID().uuidString
                let tempFileURL = tempDir.appendingPathComponent(uniqueBaseName).appendingPathExtension(fileExtension)
                
                print("MessageMedia: Saving media to temporary file: \(tempFileURL.path)")
                try data.write(to: tempFileURL)
                
                previewItemURL = tempFileURL
                print("MessageMedia: Set previewItemURL to: \(tempFileURL)")
                
            } catch {
                print("MessageMedia: Error processing media \(message.id): \(error)")
            }
        }
    }
}


