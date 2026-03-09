//
//  AppDelegate.swift
//  1TrulbargrovarStrinel
//
//  Created by Роман Главацкий on 03.03.2026.
//

import UIKit
import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging

@main
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureAppsFlyer()
        return true
    }

    private func configureAppsFlyer() {
        //AppsFlyer
        AppsFlyerLib.shared().appsFlyerDevKey = "cqTiFvvyhL5a2SNAqqAna3"
        AppsFlyerLib.shared().appleAppID = "6759949645"
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().deepLinkDelegate = self
        AppsFlyerLib.shared().start()
        
        //FireBase
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        if let app = FirebaseApp.app() {
            ConfigManagerOptionalData.firebaseProjectId = app.options.gcmSenderID
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }
}

// MARK: - MessagingDelegate
extension AppDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        ConfigManagerOptionalData.pushToken = fcmToken
        if let app = FirebaseApp.app() {
            ConfigManagerOptionalData.firebaseProjectId = app.options.gcmSenderID
        }
        if NotificationPermissionManager.shared.consumeShouldSendTokenOnce() {
            ConfigManager.shared.requestConfig { _ in
                // We don't need the response here; this call is only to deliver the push token.
            }
        }
    }
}

// MARK: - AppsFlyerLibDelegate
extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ installData: [AnyHashable: Any]) {
        AppsFlyerManager.shared.handleConversionDataSuccess(installData)
    }

    func onConversionDataFail(_ error: Error!) {
        AppsFlyerManager.shared.handleConversionDataFail(error)
    }
}

// MARK: - DeepLinkDelegate (UDL)
extension AppDelegate: DeepLinkDelegate {
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard result.status == .found, let deepLink = result.deepLink else { return }
        var payload: [AnyHashable: Any] = [:]
        for (key, value) in deepLink.clickEvent {
            payload[key] = value
        }
        payload["is_deferred"] = deepLink.isDeferred
        AppsFlyerManager.shared.handleDeepLinkData(payload)
    }
}

