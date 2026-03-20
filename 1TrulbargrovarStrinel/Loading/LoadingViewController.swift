//
//  LoadingViewController.swift
//  1TrulbargrovarStrinel
//
//  Показывает загрузку в стиле приложения (градиент + анимированный индикатор), запрашивает конфиг,
//  затем переходит на ContentView или WebviewVC. Адаптируется под портрет и ландшафт.
//  Максимальное время загрузки — 15 секунд.
//

import UIKit
import SwiftUI

/// Максимальное ожидание данных конверсии перед конфиг-запросом.
private let conversionDataWaitInterval: TimeInterval = 10
/// Окно свежести conversion-данных для fast-path при старте.
private let conversionDataFreshnessWindow: TimeInterval = 10
/// Максимальное время загрузки (сек): при нормальном интернете не должно превышать 15.
private let maxLoadingTimeInterval: TimeInterval = 15

/// Задержка перед стартом обычного config-flow (когда нет pending push URL).
private let ordinaryStartDelayInterval: TimeInterval = 5

final class LoadingViewController: UIViewController {

    private let loadingHosting = UIHostingController(rootView: AnyView(LoadingView()))
    private var didFinishTransition = false
    private var timeoutWorkItem: DispatchWorkItem?
    private var conversionWaitWorkItem: DispatchWorkItem?
    private var conversionObserver: NSObjectProtocol?
    private var didStartConfigRequest = false
    private var ordinaryStartWorkItem: DispatchWorkItem?
    /// Флаг: config-flow уже запущен (или запланирован) — повторно не стартуем.
    private var isConfigFlowInProgress = false

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
            // Push-ветка: отменяем отложенный обычный старт.
            ordinaryStartWorkItem?.cancel()
            ordinaryStartWorkItem = nil
            isConfigFlowInProgress = true
            // App launched from push. Check URL availability before opening WebView.
            PushNotificationURLRouter.shared.checkURLReachable(pushURL) { [weak self] reachable in
                guard let self = self, !self.didFinishTransition else { return }
                if reachable {
                    self.didFinishTransition = true
                    self.replaceRoot(with: WebviewVC(url: pushURL))
                } else {
                    // URL not reachable, continue with normal startup flow.
                    self.isConfigFlowInProgress = false
                    self.startConfigFlowWithoutPush()
                }
            }
            return
        }

        // Обычный старт: запускаем config-flow не сразу, а после задержки.
        // Это стабилизирует поведение на TestFlight, когда приложение уходит в background/foreground.
        guard !isConfigFlowInProgress, ordinaryStartWorkItem == nil else { return }
        isConfigFlowInProgress = true
        showLoadingState()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.ordinaryStartWorkItem = nil
            guard !self.didFinishTransition, self.isConfigFlowInProgress else { return }
            self.startConfigFlowWithoutPush()
        }
        ordinaryStartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + ordinaryStartDelayInterval, execute: workItem)
    }

    private func startConfigFlowWithoutPush() {
        if didFinishTransition { return }
        isConfigFlowInProgress = true
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

        // Таймаут: по истечении принудительно завершаем загрузку
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
        isConfigFlowInProgress = false
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
        ordinaryStartWorkItem?.cancel()
        ordinaryStartWorkItem = nil
        conversionWaitWorkItem?.cancel()
        conversionWaitWorkItem = nil
        if let observer = conversionObserver {
            NotificationCenter.default.removeObserver(observer)
            conversionObserver = nil
        }
    }

    private func finishByTimeout() {
        guard !didFinishTransition else { return }
        // If the config request already started, don't override the UI decision by timeout.
        // The request itself has its own timeout interval.
        if didStartConfigRequest { return }
        cancelTimeout()
        isConfigFlowInProgress = false
        transitionToContentViewOrSavedWebView()
    }

    private func performConfigRequest() {
        guard !didFinishTransition, !didStartConfigRequest else { return }
        didStartConfigRequest = true
        // From this point the in-flight request timeout controls the flow.
        // Prevent the global loading timeout from forcing ContentView while we are awaiting the response.
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
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
        // Fast-path только для свежих conversion-данных,
        // чтобы не использовать устаревшее значение из прошлых запусков.
        if AppsFlyerManager.shared.hasFreshConversionData(within: conversionDataFreshnessWindow) {
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

        // Stage 2: if conversion data didn't arrive in time, proceed with config request
        // without conversion payload (so we don't block UX with ContentView fallback).
        conversionWaitWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.didFinishTransition, !self.didStartConfigRequest else { return }
            if AppsFlyerManager.shared.conversionDataString == nil {
                self.performConfigRequest()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + conversionDataWaitInterval, execute: conversionWaitWorkItem!)

        // Close the race window: if data became available right before/while subscribing,
        // trigger the request immediately.
        if AppsFlyerManager.shared.hasFreshConversionData(within: conversionDataFreshnessWindow) {
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
