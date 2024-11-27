//
//  Brand.swift
//  Sticker Mania App
//
//  Created by Connor on 11/21/24.
//

import Foundation

struct Brand: Decodable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
}
