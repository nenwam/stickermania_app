//
//  ChatType.swift
//  Sticker Mania App
//
//  Created by Connor on 11/1/24.
//

import Foundation

enum ChatType: String, Decodable, Identifiable {
    case team = "team"
    case customer = "customer"

    var id: String { self.rawValue }
}
