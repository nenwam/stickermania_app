//
//  RoleSelectionView.swift
//  Sticker Mania App
//
//  Created by Connor on 12/3/24.
//

import SwiftUI

struct RoleSelectionView: View {
    let currentRole: UserRole
    let onRoleSelected: (UserRole) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let availableRoles: [UserRole] = [
        .customer,
        .employee,
        .accountManager,
        .admin,
        .suspended
    ]
    
    var body: some View {
        NavigationView {
            List(availableRoles, id: \.self) { role in
                Button(action: {
                    onRoleSelected(role)
                }) {
                    HStack {
                        Text(role.rawValue.capitalized)
                        Spacer()
                        if role == currentRole {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Role")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
}
