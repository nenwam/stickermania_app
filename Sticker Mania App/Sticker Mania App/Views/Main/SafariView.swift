//
//  SafariView.swift
//  Sticker Mania App
//
//  Created by Connor on 2/7/25.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {

    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No update needed in this case.
    }

}

#Preview {
    SafariView(url: URL(string: "https://www.google.com")!)
}
