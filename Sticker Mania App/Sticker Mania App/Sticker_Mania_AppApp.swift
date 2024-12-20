//
//  Sticker_Mania_AppApp.swift
//  Sticker Mania App
//
//  Created by Connor on 10/29/24.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
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
