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
    /// - { "message": { "data": { "url": "https://..." } } } (FCM HTTP v1 example shape)
    func extractURL(from userInfo: [AnyHashable: Any]) -> URL? {
        // 1) Top-level: { "url": "https://..." }
        if let url = parseURL(from: userInfo, key: "url") { return url }

        // 2) Top-level: { "data": { "url": "https://..." } }
        if let dataDict = userInfo["data"] as? [AnyHashable: Any],
           let url = parseURL(from: dataDict, key: "url") {
            return url
        }

        // 3) FCM HTTP v1 example shape: { "message": { "data": { "url": "https://..." } } }
        if let messageDict = userInfo["message"] as? [AnyHashable: Any] {
            // { "message": { "url": "..." } } (rare but harmless)
            if let url = parseURL(from: messageDict, key: "url") { return url }

            if let messageDataDict = messageDict["data"] as? [AnyHashable: Any],
               let url = parseURL(from: messageDataDict, key: "url") {
                return url
            }
        }

        // 4) Common string-key variants (some providers flatten custom keys)
        if let url = parseURL(from: userInfo, key: "gcm.notification.url") { return url }
        if let url = parseURL(from: userInfo, key: "custom.url") { return url }

        return nil
    }

    private func parseURL(from dict: [AnyHashable: Any], key: String) -> URL? {
        guard let raw = dict[key] else { return nil }
        let urlString: String?
        if let s = raw as? String { urlString = s }
        else if let n = raw as? NSNumber { urlString = n.stringValue }
        else { urlString = nil }

        guard let urlString, !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return URL(string: urlString)
    }

    /// Performs a quick HTTP reachability check for the given URL.
    /// Calls completion(true) if the request succeeds with 2xx/3xx status, false otherwise.
    func checkURLReachable(_ url: URL, timeout: TimeInterval = 5, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("❗️Push URL check failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            if let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) {
                DispatchQueue.main.async { completion(true) }
            } else {
                DispatchQueue.main.async { completion(false) }
            }
        }
        task.resume()
    }
}
