import SwiftUI
import WebKit

// MARK: - Нативный контроллер с исправленной геометрией и Auto Layout
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
        // Устанавливаем системный цвет фона, чтобы не было черных полос
        view.backgroundColor = .systemBackground
        setupWebView()
    }

    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        // Инъекция CSS: растягиваем сайт на 100% высоты без рамок
        let customCSS = """
        html, body {
            -webkit-user-select: text;
            -webkit-touch-callout: default;
            touch-action: manipulation;
            background-color: transparent !important;
            height: 100% !important;
            width: 100% !important;
            margin: 0 !important;
            padding: 0 !important;
        }
        .pwa-install-banner, .app-banner {
            display: none !important;
        }
        """
        
        let userScript = WKUserScript(
            source: """
            var style = document.createElement('style');
            style.innerHTML = `\(customCSS)`;
            document.head.appendChild(style);
            
            // Включаем viewport-fit=cover, чтобы убрать системные полосы
            var meta = document.querySelector('meta[name="viewport"]');
            if (meta) {
                meta.content = meta.content + ', viewport-fit=cover';
            }
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(userScript)

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .systemBackground
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = true

        // ОТКЛЮЧАЕМ системный отступ: сайт заполнит экран от верхнего до нижнего края
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // User-Agent под Mobile Safari
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"

        // ЖЕСТКАЯ ПРИВЯЗКА К ЭКРАНУ (Auto Layout)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        webView.load(URLRequest(url: targetURL))
    }

    // Обработка модальных окон (выбор фото / камеры / файлов)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    // Защита от краша по памяти (OOM) на iPhone 6S Plus
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - Главный интерфейс
struct ContentView: View {
    private let targetURL = URL(string: "https://gemini.google.com")!

    var body: some View {
        UltraWebViewControllerRepresentable(url: targetURL)
            .ignoresSafeArea()
    }
}