//
//  SceneDelegate.swift
//  1TrulbargrovarStrinel
//
//  Created by Роман Главацкий on 03.03.2026.
//

import UIKit
import SwiftUI
import AppTrackingTransparency
import AppsFlyerLib

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = LoadingManager.shared.makeRootViewController()
        window?.makeKeyAndVisible()
        handleDeepLinkConnectionOptions(connectionOptions)
    }

    // Scene-based lifecycle: deep links are delivered here.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        AppsFlyerLib.shared().handleOpen(url, options: nil)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        requestTrackingAuthorizationIfNeeded()
    }

    /// Запрос на отслеживание данных (ATT) для сбора IDFA, требуется для AppsFlyer.
    /// Показывается один раз, когда статус ещё не определён (.notDetermined).
    private func requestTrackingAuthorizationIfNeeded() {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                // Результат учтён системой; AppsFlyer получит IDFA при разрешении.
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    private func handleDeepLinkConnectionOptions(_ options: UIScene.ConnectionOptions) {
        if let urlContext = options.urlContexts.first {
            AppsFlyerLib.shared().handleOpen(urlContext.url, options: nil)
        }
        if let activity = options.userActivities.first {
            AppsFlyerLib.shared().continue(activity, restorationHandler: nil)
        }
    }

}

