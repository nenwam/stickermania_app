//
//  IdentifiableError.swift
//  Sticker Mania App
//
//  Created by Connor on 10/29/24.
//

import Foundation

struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String
}