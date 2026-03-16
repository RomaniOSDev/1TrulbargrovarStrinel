//
//  PushNotificationURLRouter.swift
//  1TrulbargrovarStrinel
//
//  Extracts URL from push payload and stores one-time pending URL.
//

import Foundation

final class PushNotificationURLRouter {
    static let shared = PushNotificationURLRouter()

    private init() {}

    private var pendingURL: URL?

    func setPendingURL(_ url: URL) {
        pendingURL = url
    }

    func consumePendingURL() -> URL? {
        defer { pendingURL = nil }
        return pendingURL
    }

    /// Supports both payload shapes:
    /// - { "url": "https://..." }
    /// - { "data": { "url": "https://..." } }
    func extractURL(from userInfo: [AnyHashable: Any]) -> URL? {
        if let urlString = userInfo["url"] as? String,
           let url = URL(string: urlString), !urlString.isEmpty {
            return url
        }

        if let dataDict = userInfo["data"] as? [AnyHashable: Any],
           let urlString = dataDict["url"] as? String,
           let url = URL(string: urlString), !urlString.isEmpty {
            return url
        }

        return nil
    }
}
