import SwiftUI
import WebKit

// MARK: - Нативный контроллер с поддержкой загрузки файлов и модалок
struct UltraWebViewControllerRepresentable: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> WebViewController {
        let vc = WebViewController()
        vc.targetURL = url
        return vc
    }

    func updateUIViewController(_ uiViewController: WebViewController, context: Context) {}
}

class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    var webView: WKWebView!
    var targetURL: URL!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
    }

    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Разрешаем веб-скриптам открывать системные диалоговые окна
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        // Инъекция CSS: убираем лишний веб-отступ, настраиваем Safe Area и плавный скролл
        let customCSS = """
        html, body {
            -webkit-user-select: text;
            -webkit-touch-callout: default;
            touch-action: manipulation;
        }
        /* Скрываем плашки принудительной установки веб-приложения, если они есть */
        .pwa-install-banner, .app-banner {
            display: none !important;
        }
        """
        let userScript = WKUserScript(source: "var style = document.createElement('style'); style.innerHTML = `\(customCSS)`; document.head.appendChild(style);", injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(userScript)

        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // ВАЖНО: подключаем оба делегата
        webView.navigationDelegate = self
        webView.uiDelegate = self

        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = true

        // User-Agent под Mobile Safari
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"

        view.addSubview(webView)
        webView.load(URLRequest(url: targetURL))
    }

    // MARK: - WKUIDelegate: Обработка модальных окон (выбор фото / камеры / файлов)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    // Защита от черного экрана: если WebContent крашнулся по памяти на 6S Plus
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print("WebKit process terminated (OOM). Auto-reloading...")
        webView.reload()
    }
}

// MARK: - Главный интерфейс (На весь экран, без полей браузера)
struct ContentView: View {
    private let targetURL = URL(string: "https://gemini.google.com")!

    var body: some View {
        UltraWebViewControllerRepresentable(url: targetURL)
            .ignoresSafeArea(.all)
    }
}