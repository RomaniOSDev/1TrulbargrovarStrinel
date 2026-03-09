//
//  NotificationPermissionManager.swift
//  1TrulbargrovarStrinel
//
//  Stores when the user declined the custom notification screen.
//  Custom screen is hidden for 3 days after decline.
//

import Foundation

enum NotificationPermissionKeys {
    static let lastCustomDeclineDate = "NotificationPermissionLastCustomDeclineDate"
    static let shouldSendTokenOnce = "NotificationPermissionShouldSendTokenOnce"
}

private let customDeclineCooldownDays: Int = 3

final class NotificationPermissionManager {

    static let shared = NotificationPermissionManager()

    private init() {}

    /// Call when user taps "Decline" on the custom notification screen.
    func recordCustomDecline() {
        UserDefaults.standard.set(Date(), forKey: NotificationPermissionKeys.lastCustomDeclineDate)
    }

    /// Mark that after the next FCM token reception we should send config once with push token.
    func markShouldSendTokenOnce() {
        UserDefaults.standard.set(true, forKey: NotificationPermissionKeys.shouldSendTokenOnce)
    }

    /// Returns true once when a token-triggered config request should be sent, then resets the flag.
    func consumeShouldSendTokenOnce() -> Bool {
        let flag = UserDefaults.standard.bool(forKey: NotificationPermissionKeys.shouldSendTokenOnce)
        if flag {
            UserDefaults.standard.set(false, forKey: NotificationPermissionKeys.shouldSendTokenOnce)
        }
        return flag
    }

    /// Whether the custom notification screen should be shown before WebView.
    /// Returns false for 3 days after a custom decline.
    var shouldShowCustomNotificationScreen: Bool {
        guard let date = UserDefaults.standard.object(forKey: NotificationPermissionKeys.lastCustomDeclineDate) as? Date else {
            return true
        }
        let interval = Date().timeIntervalSince(date)
        let threeDays: TimeInterval = TimeInterval(customDeclineCooldownDays * 24 * 60 * 60)
        return interval >= threeDays
    }
}
