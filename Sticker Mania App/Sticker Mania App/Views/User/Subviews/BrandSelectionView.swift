//
//  BrandSelectionView.swift
//  Sticker Mania App
//
//  Created by Connor on 11/26/24.
//

import SwiftUI

struct BrandSelectionView: View {
    @State private var selectedBrands: [Brand]
    @State private var newBrandName = ""
    
    var onSave: ([Brand]) -> Void
    
    init(selectedBrands: [Brand], onSave: @escaping ([Brand]) -> Void) {
        _selectedBrands = State(initialValue: selectedBrands)
        self.onSave = onSave
    }
    
    var body: some View {
        List {
            Section(header: Text("Add New Brand")) {
                HStack {
                    TextField("Brand name", text: $newBrandName)
                    Button(action: {
                        if !newBrandName.isEmpty {
                            let newBrand = Brand(id: UUID().uuidString, name: newBrandName)
                            selectedBrands.append(newBrand)
                            newBrandName = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                    .disabled(newBrandName.isEmpty)
                }
            }
            
            Section(header: Text("Current Brands")) {
                if selectedBrands.isEmpty {
                    Text("No brands associated")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(selectedBrands) { brand in
                        HStack {
                            Text(brand.name)
                            Spacer()
                            Button(action: {
                                selectedBrands.removeAll(where: { $0.id == brand.id })
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedBrands) { newValue in
            onSave(newValue)
        }
    }
}

#Preview {
    NavigationView {
        BrandSelectionView(
            selectedBrands: [Brand(id: "1", name: "Brand 1")],
            onSave: { _ in }
        )
    }
}
