//
//  PayReviewApp.swift
//  PayReview
//
//  Created by 廖為 on 2026/7/16.
//

import SwiftUI
import GoogleSignIn

@main
struct PayReviewApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) private var firebaseAppDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
