import UIKit
import WebKit

final class WebviewVC: UIViewController, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {

    private static let sharedProcessPool = WKProcessPool()

    // MARK: - Properties
    private var webView: WKWebView!
    private let startURL: URL
    private var lastRedirectURL: URL?
    private var didLoadInitialURL = false

    /// Resolves http(s) as-is; relative paths (e.g. `fourthpage` from `window.open`) against the current document URL.
    private func resolvePossiblyRelativeURL(_ url: URL, relativeTo baseURL: URL?) -> URL? {
        let scheme = (url.scheme ?? "").lowercased()
        if scheme == "http" || scheme == "https" {
            return url
        }
        guard let baseURL else { return nil }
        let raw = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        if let resolved = URL(string: raw, relativeTo: baseURL)?.absoluteURL {
            return resolved
        }
        if !url.path.isEmpty, url.path != "/", let resolved = URL(string: url.path, relativeTo: baseURL)?.absoluteURL {
            return resolved
        }
        return nil
    }

    // MARK: - Init
    init(url: URL) {
        self.startURL = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        //PushManager().requestAuthorization()
        setupWebView()
        setupGestures()
        configureUserAgentAndLoad()
        
    }

    // MARK: - Setup
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.processPool = Self.sharedProcessPool

        webView = WKWebView(frame: .zero, configuration: config)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true // встроенный свайп
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.delegate = self
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false

        view.addSubview(webView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            webView.topAnchor.constraint(equalTo: guide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
        ])
    }

    private func configureUserAgentAndLoad() {
        guard !didLoadInitialURL else { return }
        didLoadInitialURL = true
        loadURL(startURL)
    }

    private func setupGestures() {
        // Дополнительный свайп-вправо (если встроенный не сработает)
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
    }

    @objc private func handleSwipeRight() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    private func loadURL(_ url: URL) {
        print("🌍 Загружаем: \(url.absoluteString)")
        let request = URLRequest(url: url)
        webView.load(request)
    }

    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            // Don't cancel when URL is missing; canceling may leave the main document blank.
            decisionHandler(.allow)
            return
        }
        lastRedirectURL = url // сохраняем последнюю попытку перехода

        let scheme = (url.scheme ?? "").lowercased()
        let isHttp = scheme == "http" || scheme == "https"
        let isUserTap = navigationAction.navigationType == .linkActivated
        let hasScheme = !(url.scheme ?? "").isEmpty

        // target="_blank" / window.open (в т.ч. script-initiated): всегда в этом же WKWebView,
        // иначе WebKit создаёт пустой WebPage и relative URL даёт requestURLIsValid = 0.
        if navigationAction.targetFrame == nil {
            if isHttp {
                webView.load(URLRequest(url: url))
                decisionHandler(.cancel)
                return
            }
            if let resolved = resolvePossiblyRelativeURL(url, relativeTo: webView.url) {
                webView.load(URLRequest(url: resolved))
                decisionHandler(.cancel)
                return
            }
            if hasScheme, scheme != "about" {
                openExternalURL(url, showAlert: true)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
            return
        }

        // Custom schemes: обрабатываем только по реальному пользовательскому тапу.
        if !isHttp && isUserTap {
            if let resolved = resolvePossiblyRelativeURL(url, relativeTo: webView.url) {
                webView.load(URLRequest(url: resolved))
                decisionHandler(.cancel)
                return
            }
            if hasScheme {
                openExternalURL(url, showAlert: true)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url {
            print("➡️ Начата загрузка: \(url.absoluteString)")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            print("✅ Успешно загружено: \(url.absoluteString)")
            lastRedirectURL = url // обновляем успешную ссылку
        }
        disablePageZoom()
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {

        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain &&
            nsError.code == NSURLErrorHTTPTooManyRedirects {

            // Берём последнюю известную ссылку
            if let url = lastRedirectURL ?? webView.url {
                print("⚠️ ERR_TOO_MANY_REDIRECTS → пробуем перезагрузить \(url.absoluteString)")

                // Перезагружаем после небольшой задержки
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.webView.load(URLRequest(url: url))
                }
            } else {
                print("❌ Нет URL для перезагрузки после редиректа")
            }
        } else {
            print("❗️Ошибка загрузки: \(nsError.localizedDescription)")
        }
    }

    // MARK: - Zoom control
    private func openExternalURL(_ url: URL, showAlert: Bool) {
        let application = UIApplication.shared
        if application.canOpenURL(url) {
            application.open(url, options: [:]) { [weak self] success in
                if !success, showAlert {
                    self?.showAppNotInstalledAlert()
                }
            }
        } else {
            // For unknown schemes iOS may return false; still try open, then alert on failure.
            application.open(url, options: [:]) { [weak self] success in
                if !success, showAlert {
                    self?.showAppNotInstalledAlert()
                }
            }
        }
    }

    private func showAppNotInstalledAlert() {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: "Cannot Open Link",
            message: "The required app is not installed on this device.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func disablePageZoom() {
        let script = """
        (function() {
            var meta = document.querySelector('meta[name=viewport]');
            if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                document.head.appendChild(meta);
            }
            meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        nil
    }

    // MARK: - WKUIDelegate
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        // window.open / target=_blank: не создаём второй WKWebView (он не в иерархии и ломает relative URL).
        // Script-initiated вызовы — не .linkActivated; всё равно грузим в текущий webView.
        guard let url = navigationAction.request.url else { return nil }
        let scheme = (url.scheme ?? "").lowercased()
        let isHttp = scheme == "http" || scheme == "https"
        let hasScheme = !(url.scheme ?? "").isEmpty

        if isHttp {
            webView.load(URLRequest(url: url))
            return nil
        }
        // about:blank для пустого окна — не грузим; последующий request придёт отдельно
        if scheme == "about" {
            return nil
        }
        if let resolved = resolvePossiblyRelativeURL(url, relativeTo: webView.url) {
            webView.load(URLRequest(url: resolved))
            return nil
        }
        if hasScheme {
            openExternalURL(url, showAlert: true)
        }
        return nil
    }
}

// MARK: - Redirect Detector
private final class RedirectDetectorDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // разрешаем максимум 20 редиректов (система отлавливает сама)
        completionHandler(request)
    }
}


// MARK: - SaveService
struct SaveService {
    static var lastUrl: URL? {
        get { UserDefaults.standard.url(forKey: "LastUrl") }
        set { UserDefaults.standard.set(newValue, forKey: "LastUrl") }
    }

    static var time: String? {
        get { UserDefaults.standard.string(forKey: "Time") }
        set { UserDefaults.standard.set(newValue, forKey: "Time") }
    }
}
