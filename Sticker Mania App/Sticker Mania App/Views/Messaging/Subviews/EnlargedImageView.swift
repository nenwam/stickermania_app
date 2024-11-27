import SwiftUI

struct EnlargedImageView: View {
    let imageUrl: URL
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showingAlert = false
    
    var body: some View {
        VStack {
            AsyncImage(url: imageUrl) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 4)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                case .failure:
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .padding()
            
            Button(action: {
                Task {
                    do {
                        let data = try Data(contentsOf: imageUrl)
                        let image = UIImage(data: data)
                        UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
                        showingAlert = true
                    } catch {
                        print("Error saving image: \(error)")
                    }
                }
            }) {
                Label("Save Image", systemImage: "square.and.arrow.down")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .alert("Success", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Image saved to photo library")
        }
    }
}
