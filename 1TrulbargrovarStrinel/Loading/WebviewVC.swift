import UIKit
import WebKit

final class WebviewVC: UIViewController, WKNavigationDelegate {

    // MARK: - Properties
    private var webView: WKWebView!
    private let startURL: URL
    private var lastRedirectURL: URL?

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
        //PushManager().requestAuthorization()
        setupWebView()
        setupGestures()
        loadURL(startURL)
        
    }

    // MARK: - Setup
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = UserAgentBuilder.build()
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true // встроенный свайп

        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
        if let url = navigationAction.request.url {
            lastRedirectURL = url // сохраняем последнюю попытку перехода
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
