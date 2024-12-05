// Helpers/Permissions/PermissionManager.swift
class PermissionManager {
    static func canMessage(user: User, targetRole: UserRole) -> Bool {
        switch user.role {
        case .customer:
            return targetRole == .customer
        case .accountManager, .employee:
            return targetRole == .employee || targetRole == .accountManager
        case .suspended:
            return false
        case .admin:
            return true
        }
    }
    
    static func canManageOrders(user: User) -> Bool {
        return user.role == .accountManager || user.role == .admin
    }
    
    static func canCreateOrDeleteUsers(user: User) -> Bool {
        return user.role == .admin
    }
    
    // Add more permission checks as needed
}