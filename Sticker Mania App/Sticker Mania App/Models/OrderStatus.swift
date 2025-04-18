import Foundation

enum OrderStatus: String, CaseIterable {
    case pending
    case inProgress
    case flagged
    case completed
}