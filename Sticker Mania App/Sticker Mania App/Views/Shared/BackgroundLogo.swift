//
//  BackgroundLogo.swift
//  Sticker Mania App
//
//  Created by Connor on 12/4/24.
//

import SwiftUI

struct BackgroundLogo: View {
    let opacity: CGFloat

    var body: some View {
        VStack {
            Spacer()
            Image("sm_bg_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 200)
                .opacity(opacity)
                .padding(.bottom, 20)
        }
    }
}

#Preview {
    BackgroundLogo(opacity: 0.2)
}
