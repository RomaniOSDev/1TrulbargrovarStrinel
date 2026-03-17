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
