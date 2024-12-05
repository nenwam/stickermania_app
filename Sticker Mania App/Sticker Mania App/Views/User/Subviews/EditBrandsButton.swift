//
//  EditBrandsButton.swift
//  Sticker Mania App
//
//  Created by Connor on 12/2/24.
//

import SwiftUI

struct EditBrandsButton: View {
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.blue)
                Text("Edit Brands")
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

#Preview {
    EditBrandsButton(
        onEdit: {}
    )
}
