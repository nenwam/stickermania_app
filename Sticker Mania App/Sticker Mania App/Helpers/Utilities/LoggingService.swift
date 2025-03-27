import Foundation
import FirebaseCrashlytics
import FirebaseAnalytics

class LoggingService {
    static let shared = LoggingService()
    
    enum LogLevel: String {
        case debug, info, warning, error, critical
    }
    
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(level.rawValue.uppercased())] [\(fileName):\(line) \(function)] - \(message)"
        
        // Console logging in debug mode
        #if DEBUG
        print(logMessage)
        #endif
        
        // Always log to Crashlytics for production monitoring
        Crashlytics.crashlytics().log(logMessage)
        
        // For errors and critical issues, record non-fatal errors
        if level == .error || level == .critical {
            let userInfo = [
                NSLocalizedDescriptionKey: message,
                "file": fileName,
                "function": function,
                "line": "\(line)"
            ]
            let error = NSError(domain: "StickersManiaApp", code: level == .critical ? 2 : 1, userInfo: userInfo)
            Crashlytics.crashlytics().record(error: error)
        }
        
        // Log significant events to Analytics
        if level != .debug {
            Analytics.logEvent("app_log_\(level.rawValue)", parameters: [
                "message": message,
                "file": fileName,
                "function": function
            ])
        }
    }
    
    // Additional method for logging user actions
    func logUserAction(_ action: String, parameters: [String: Any]? = nil) {
        Crashlytics.crashlytics().log("USER ACTION: \(action)")
        Analytics.logEvent(action, parameters: parameters)
    }
    
    // Method to set up user context for better logging
    func setUserContext(userId: String, email: String, name: String, role: String) {
        Crashlytics.crashlytics().setUserID(userId)
        Crashlytics.crashlytics().setCustomValue(email, forKey: "user_email")
        Crashlytics.crashlytics().setCustomValue(name, forKey: "user_name")
        Crashlytics.crashlytics().setCustomValue(role, forKey: "user_role")
        
        // Also set user properties in Analytics
        Analytics.setUserProperty(role, forName: "user_role")
        Analytics.setUserID(userId)
    }
    
    // Method to clear user context
    func clearUserContext() {
        Crashlytics.crashlytics().setUserID("")
        Crashlytics.crashlytics().setCustomKeysAndValues([:])
        Analytics.setUserID(nil)
    }
}
