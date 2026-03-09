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

/// Задержка (сек) перед запросом конфига, чтобы успеть получить данные конверсии от AppsFlyer.
private let conversionDataWaitInterval: TimeInterval = 3
/// Максимальное время загрузки (сек): при нормальном интернете не должно превышать 10.
private let maxLoadingTimeInterval: TimeInterval = 10

final class LoadingViewController: UIViewController {

    private let loadingHosting = UIHostingController(rootView: LoadingView())
    private var didFinishTransition = false
    private var timeoutWorkItem: DispatchWorkItem?

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

        let config = ConfigManager.shared

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

        // Ждём возможного прихода данных конверсии, затем запрашиваем конфиг
        DispatchQueue.main.asyncAfter(deadline: .now() + conversionDataWaitInterval) { [weak self] in
            self?.performConfigRequest()
        }
    }

    private func cancelTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }

    private func finishByTimeout() {
        guard !didFinishTransition else { return }
        cancelTimeout()
        transitionToContentViewOrSavedWebView()
    }

    private func performConfigRequest() {
        guard !didFinishTransition else { return }

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

    /// При ошибке: если есть сохранённая ссылка — WebView с ней, иначе — ContentView.
    private func transitionToContentViewOrSavedWebView() {
        if let url = ConfigManager.shared.savedURL {
            transitionToWebView(url: url)
        } else {
            transitionToContentView()
        }
    }

    private func transitionToWebView(url: URL) {
        didFinishTransition = true
        if NotificationPermissionManager.shared.shouldShowCustomNotificationScreen {
            let notificationVC = NotificationPermissionViewController(url: url, window: view.window)
            replaceRoot(with: notificationVC)
        } else {
            replaceRoot(with: WebviewVC(url: url))
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
