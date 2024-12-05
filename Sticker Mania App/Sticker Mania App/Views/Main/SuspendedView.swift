//
//  SuspendedView.swift
//  Sticker Mania App
//
//  Created by Connor on 12/3/24.
//

import SwiftUI
import FirebaseAuth

struct SuspendedView: View {
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Account Suspended")
                .font(.title)
                .bold()
            
            Text("Your account has been suspended. Please contact support for assistance.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            Button(action: {
                AuthenticationService.shared.signOut { _ in }
            }) {
                Text("Log Out")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    SuspendedView()
        .environmentObject(AuthViewModel())
}
