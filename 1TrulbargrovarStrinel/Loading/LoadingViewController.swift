//
//  LoadingViewController.swift
//  1TrulbargrovarStrinel
//
//  Показывает загрузку в стиле приложения (градиент + анимированный индикатор), запрашивает конфиг,
//  затем переходит на ContentView или WebviewVC. Адаптируется под портрет и ландшафт.
//  Максимальное время загрузки — 10 секунд.
//

import UIKit
import SwiftUI

/// Максимальное ожидание данных конверсии перед конфиг-запросом.
private let conversionDataWaitInterval: TimeInterval = 10
/// Максимальное время загрузки (сек): при нормальном интернете не должно превышать 20.
private let maxLoadingTimeInterval: TimeInterval = 20

final class LoadingViewController: UIViewController {

    private let loadingHosting = UIHostingController(rootView: AnyView(LoadingView()))
    private var didFinishTransition = false
    private var timeoutWorkItem: DispatchWorkItem?
    private var conversionWaitWorkItem: DispatchWorkItem?
    private var conversionObserver: NSObjectProtocol?
    private var didStartConfigRequest = false

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(loadingHosting)
        view.addSubview(loadingHosting.view)
        loadingHosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingHosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingHosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingHosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            loadingHosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        loadingHosting.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startConfigFlow()
    }

    private func startConfigFlow() {
        if didFinishTransition { return }
        if let pushURL = PushNotificationURLRouter.shared.consumePendingURL() {
            // App launched from push. Check URL availability before opening WebView.
            PushNotificationURLRouter.shared.checkURLReachable(pushURL) { [weak self] reachable in
                guard let self = self, !self.didFinishTransition else { return }
                if reachable {
                    self.didFinishTransition = true
                    self.replaceRoot(with: WebviewVC(url: pushURL))
                } else {
                    // URL not reachable, continue with normal startup flow.
                    self.startConfigFlowWithoutPush()
                }
            }
            return
        }
        startConfigFlowWithoutPush()
    }

    private func startConfigFlowWithoutPush() {
        if didFinishTransition { return }
        showLoadingState()

        NetworkAvailability.checkConnection { [weak self] isConnected in
            guard let self = self, !self.didFinishTransition else { return }
            if !isConnected {
                self.showNoInternetState()
                return
            }
            self.startConfigFlowWithInternet()
        }
    }

    private func startConfigFlowWithInternet() {
        if didFinishTransition { return }
        let config = ConfigManager.shared
        didStartConfigRequest = false

        // Таймаут 10 сек: по истечении принудительно завершаем загрузку
        timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.finishByTimeout()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + maxLoadingTimeInterval, execute: timeoutWorkItem!)

        // Есть действительная сохранённая ссылка — сразу показываем WebView
        if config.isSavedURLValid, let url = config.savedURL {
            cancelTimeout()
            transitionToWebView(url: url)
            return
        }

        waitForConversionDataThenRequestConfig()
    }

    private func showLoadingState() {
        loadingHosting.rootView = AnyView(LoadingView())
    }

    private func showNoInternetState() {
        cancelTimeout()
        loadingHosting.rootView = AnyView(
            NoInternetView(
                onRetry: { [weak self] in
                    self?.startConfigFlow()
                }
            )
        )
    }

    private func cancelTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        conversionWaitWorkItem?.cancel()
        conversionWaitWorkItem = nil
        if let observer = conversionObserver {
            NotificationCenter.default.removeObserver(observer)
            conversionObserver = nil
        }
    }

    private func finishByTimeout() {
        guard !didFinishTransition else { return }
        cancelTimeout()
        transitionToContentViewOrSavedWebView()
    }

    private func performConfigRequest() {
        guard !didFinishTransition, !didStartConfigRequest else { return }
        didStartConfigRequest = true
        conversionWaitWorkItem?.cancel()
        conversionWaitWorkItem = nil
        if let observer = conversionObserver {
            NotificationCenter.default.removeObserver(observer)
            conversionObserver = nil
        }

        ConfigManager.shared.requestConfig { [weak self] result in
            guard let self = self, !self.didFinishTransition else { return }
            self.cancelTimeout()
            switch result {
            case .success(let response):
                if response.ok, let urlString = response.url, let url = URL(string: urlString) {
                    self.transitionToWebView(url: url)
                } else {
                    self.transitionToContentViewOrSavedWebView()
                }
            case .failure:
                self.transitionToContentViewOrSavedWebView()
            }
        }
    }

    private func waitForConversionDataThenRequestConfig() {
        // Fast-path: data already available.
        if AppsFlyerManager.shared.conversionDataString != nil {
            performConfigRequest()
            return
        }

        // Subscribe first, then re-check to avoid a race where AppsFlyer posts the notification
        // between the initial nil check and observer registration.
        conversionObserver = NotificationCenter.default.addObserver(
            forName: .appsFlyerConversionDataReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.performConfigRequest()
        }

        // Close the race window: if data became available right before/while subscribing,
        // trigger the request immediately.
        if AppsFlyerManager.shared.conversionDataString != nil {
            performConfigRequest()
        }
    }

    /// При ошибке: если есть сохранённая ссылка — WebView с ней, иначе — ContentView.
    private func transitionToContentViewOrSavedWebView() {
        if let url = ConfigManager.shared.savedURL {
            transitionToWebView(url: url)
        } else {
            transitionToContentView()
        }
    }

    private func transitionToWebView(url: URL) {
        NotificationPermissionManager.shared.shouldShowCustomNotificationScreen { [weak self] shouldShow in
            guard let self = self, !self.didFinishTransition else { return }
            self.didFinishTransition = true
            if shouldShow {
                let notificationVC = NotificationPermissionViewController(url: url, window: self.view.window)
                self.replaceRoot(with: notificationVC)
            } else {
                self.replaceRoot(with: WebviewVC(url: url))
            }
        }
    }

    private func transitionToContentView() {
        didFinishTransition = true
        let content = UIHostingController(rootView: ContentView())
        replaceRoot(with: content)
    }

    private func replaceRoot(with vc: UIViewController) {
        guard let window = view.window else { return }
        window.rootViewController = vc
    }
}
