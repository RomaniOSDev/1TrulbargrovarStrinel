//
//  AppsFlyerManager.swift
//  1TrulbargrovarStrinel
//
//  Менеджер AppsFlyer: получение данных конверсии и UDL, сохранение в строку для отправки на сервер.
//  При af_status == "Organic" выполняется повторный запрос конверсии через 5 секунд (Get the conversion data).
//

import Foundation
import AppsFlyerLib

extension Notification.Name {
    static let appsFlyerConversionDataReady = Notification.Name("appsFlyerConversionDataReady")
}

/// Ключ для сохранения строки с данными конверсии (для отправки на сервер)
enum AppsFlyerManagerKeys {
    static let conversionDataString = "AppsFlyerConversionDataString"
}

/// Менеджер AppsFlyer: конверсия + UDL. Не изменяет набор параметров из ответа.
final class AppsFlyerManager: NSObject {

    static let shared = AppsFlyerManager()

    /// Строка с данными конверсии (и при наличии — UDL) в формате JSON для отправки на сервер.
    /// Используются первые полученные значения при совпадении ключей (сначала конверсия, затем UDL).
    private(set) var conversionDataString: String? {
        get {
            UserDefaults.standard.string(forKey: AppsFlyerManagerKeys.conversionDataString)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppsFlyerManagerKeys.conversionDataString)
        }
    }

    /// Текущие сырые данные конверсии (для слияния с UDL и повторной проверки)
    private var currentConversionData: [AnyHashable: Any]?

    /// Флаг: ожидаем повторный запрос конверсии через 5 сек из‑за Organic
    private var isRetryScheduled = false

    /// Задержка перед повторным запросом конверсии при Organic (секунды)
    private let organicRetryDelay: TimeInterval = 5

    private override init() {
        super.init()
    }

    // MARK: - Обработка конверсии (AppsFlyerLibDelegate вызывается из AppDelegate)

    /// Вызывать при успешном получении данных конверсии (onConversionDataSuccess).
    /// Сохраняет данные без изменения набора параметров. При af_status == "Organic" планирует повтор через 5 сек.
    func handleConversionDataSuccess(_ installData: [AnyHashable: Any]) {
        // Первые полученные данные имеют приоритет — сохраняем только если ещё не сохраняли итоговую строку из конверсии
        let status = installData["af_status"] as? String
        if status == "Organic" && !isRetryScheduled {
            isRetryScheduled = true
            currentConversionData = installData
            scheduleConversionDataRetry()
            return
        }

        applyConversionData(installData)
    }

    /// Вызывать при ошибке получения конверсии (onConversionDataFail).
    func handleConversionDataFail(_ error: Error?) {
        // При ошибке можно сохранить пустой объект или не менять предыдущее значение — по необходимости
    }

    /// Применить данные конверсии: слить с уже имеющимися UDL и сохранить итог в строку.
    /// Не изменяет список ключей из ответа; при совпадении ключей используются первые полученные значения.
    private func applyConversionData(_ installData: [AnyHashable: Any]) {
        currentConversionData = installData
        mergeAndSaveConversionString()
    }

    /// Повторный запрос конверсии через 5 секунд (Get the conversion data).
    private func scheduleConversionDataRetry() {
        DispatchQueue.main.asyncAfter(deadline: .now() + organicRetryDelay) { [weak self] in
            self?.performConversionDataRetry()
        }
    }

    /// Выполнить повторный запрос конверсии через API SDK (start with completionHandler).
    private func performConversionDataRetry() {
        AppsFlyerLib.shared().start(completionHandler: { [weak self] dictionary, error in
            DispatchQueue.main.async {
                if let dict = dictionary, !dict.isEmpty {
                    self?.applyConversionData(dict as [AnyHashable: Any])
                } else if let data = self?.currentConversionData {
                    // Если повторный вызов не вернул данные — сохраняем то, что было (Organic)
                    self?.mergeAndSaveConversionString()
                }
                self?.isRetryScheduled = false
            }
        })
    }

    // MARK: - Deep linking (UDL)

    /// Данные UDL для слияния с конверсией. При совпадении ключей приоритет у уже сохранённых (первые полученные).
    private var deepLinkData: [AnyHashable: Any]?

    /// Вызывать при успешном разрешении deep link (didResolveDeepLink, status == .found).
    /// Передавать словарь из DeepLink (clickEvent и т.д.) в виде [AnyHashable: Any].
    func handleDeepLinkData(_ deepLinkPayload: [AnyHashable: Any]) {
        deepLinkData = deepLinkPayload
        mergeAndSaveConversionString()
    }

    /// Слить конверсию и UDL: сначала конверсия, затем UDL; при совпадении ключа оставляем первое значение.
    /// Результат сохраняется в conversionDataString в виде JSON-строки.
    private func mergeAndSaveConversionString() {
        var merged: [String: Any] = [:]

        if let conversion = currentConversionData {
            for (key, value) in conversion {
                guard let k = key as? String else { continue }
                if merged[k] == nil {
                    merged[k] = value
                }
            }
        }

        if let udl = deepLinkData {
            for (key, value) in udl {
                guard let k = key as? String else { continue }
                if merged[k] == nil {
                    merged[k] = value
                }
            }
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: merged),
              let string = String(data: jsonData, encoding: .utf8) else {
            return
        }
        conversionDataString = string
        NotificationCenter.default.post(name: .appsFlyerConversionDataReady, object: nil)
    }

    /// Сброс сохранённой строки (например для тестов).
    func clearStoredConversionString() {
        conversionDataString = nil
        currentConversionData = nil
        deepLinkData = nil
        isRetryScheduled = false
    }
}
