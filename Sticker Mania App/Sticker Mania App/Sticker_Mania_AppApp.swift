//
//  Sticker_Mania_AppApp.swift
//  Sticker Mania App
//
//  Created by Connor on 10/29/24.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseCrashlytics
import UserNotifications
import FirebaseMessaging
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
      
      // Force Firebase to use IPv4 connections only
      let firebaseSettings = UserDefaults.standard
      firebaseSettings.set(true, forKey: "firebase:useIPv4Only")
      firebaseSettings.synchronize()
      
    FirebaseApp.configure()
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    
    // Set up notifications
    UNUserNotificationCenter.current().delegate = self
    
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
        if granted {
            LoggingService.shared.log("User granted permission for notifications")
            
            // Only register for remote notifications after permission is granted
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } else {
            LoggingService.shared.log("User denied permission for notifications: \(error?.localizedDescription ?? "Unknown error")", level: .warning)
        }
    }
    
    // Configure Firebase Messaging
    Messaging.messaging().delegate = self
    
    return true
  }
  
  // Handle FCM token refresh
  // In AppDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // ---> THIS IS THE CRITICAL LOG TO CHECK FOR <---
        LoggingService.shared.log("AppDelegate: messaging delegate called. Raw token: \(fcmToken ?? "NIL")")
        print("AppDelegate: messaging delegate called. Raw token: \(fcmToken ?? "NIL")") // Add direct print too

        if let token = fcmToken {
            LoggingService.shared.log("Firebase registration token: \(token)")
            saveUserFCMToken(token)
        } else {
            LoggingService.shared.log("AppDelegate: messaging delegate called but token was nil.", level: .warning)
            print("AppDelegate: messaging delegate called but token was nil.") // Add direct print
        }
    }
  
  // Store the FCM token in Firestore for the current user
  func saveUserFCMToken(_ token: String) {
    guard let userEmail = Auth.auth().currentUser?.email else { 
        LoggingService.shared.log("No user signed in to save FCM token", level: .warning)
        return 
    }
    
    let db = Firestore.firestore()
    let userRef = db.collection("users").document(userEmail)
    
    // First check if document exists
    userRef.getDocument { snapshot, error in
        if let error = error {
            LoggingService.shared.log("Error checking user document: \(error.localizedDescription)", level: .error)
            return
        }
        
        if snapshot?.exists == true {
            // Document exists, update it
            userRef.updateData(["fcmToken": token]) { error in
                if let error = error {
                    LoggingService.shared.log("Error updating FCM token: \(error.localizedDescription)", level: .error)
                } else {
                    LoggingService.shared.log("FCM token updated successfully for user: \(userEmail)")
                }
            }
        } else {
            // Document doesn't exist, create it
            userRef.setData(["email": userEmail, "fcmToken": token]) { error in
                if let error = error {
                    LoggingService.shared.log("Error creating user document with FCM token: \(error.localizedDescription)", level: .error)
                } else {
                    LoggingService.shared.log("Created new user document with FCM token for: \(userEmail)")
                }
            }
        }
    }
  }
  
  // Handle foreground notifications
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, 
                          withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    LoggingService.shared.log("Received notification in foreground: \(userInfo)")
    
    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
        // For iOS 14+, use banner and list
        completionHandler([.banner, .list, .sound, .badge])
    } else {
        // For earlier iOS versions, use alert
        completionHandler([.alert, .sound, .badge])
    }
}
  
  // Handle notification tap
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, 
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    LoggingService.shared.log("User tapped notification with userInfo: \(userInfo)")
    
    // Try to extract chatId from different possible locations in the payload
    var chatId: String? = nil
    
    // Check in top-level userInfo
    if let id = userInfo["chatId"] as? String {
        chatId = id
    }
    
    // Check in FCM data payload
    else if let data = userInfo["data"] as? [String: Any], 
            let id = data["chatId"] as? String {
        chatId = id
    }
    
    // Check in FCM apns-payload
    else if let aps = userInfo["aps"] as? [String: Any], 
            let data = aps["data"] as? [String: Any], 
            let id = data["chatId"] as? String {
        chatId = id
    }
    
    if let chatId = chatId {
        LoggingService.shared.log("User tapped notification for chat: \(chatId)")
        
        // Post notification to navigate to this chat
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("OpenChat"), 
                object: nil, 
                userInfo: ["chatId": chatId]
            )
        }
    } else {
        LoggingService.shared.log("No chatId found in notification: \(userInfo)", level: .warning)
    }
    
    completionHandler()
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("DEBUG: APNS device token: \(token)")
    Messaging.messaging().apnsToken = deviceToken
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("DEBUG: Failed to register for remote notifications: \(error.localizedDescription)")
  }
}

@main
struct Sticker_Mania_AppApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
          if authViewModel.isUserSignedIn {
                if let role = authViewModel.userRole {
                    switch role {
                    case .employee, .accountManager, .admin:
                        HomeView() // Full application view
                    case .customer:
                        CustomerHomeView() // Only messages page
                    case .suspended:
                        SuspendedView()
                    }
                }
            } else {
                LoginView()
            }
        // HomeView()
        }	
    }
}
