//
//  VideoThumbnailView.swift
//  Sticker Mania App
//
//  Created by Connor on 11/21/24.
//

import SwiftUI
import AVKit
struct VideoThumbnailView: View {
    let videoURL: URL
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    )
            } else {
                Color.gray
                    .overlay(
                        ProgressView()
                    )
                    .onAppear {
                        generateThumbnail()
                    }
            }
        }
    }
    
    private func generateThumbnail() {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            thumbnailImage = UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error)")
        }
    }
}
