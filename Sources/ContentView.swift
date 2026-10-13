import SwiftUI
import WebKit

// MARK: - Нативный контроллер с отступом под статус-бар
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
        // Фон статус-бара автоматически подстроится под системную тему (белый / темный)
        view.backgroundColor = .systemBackground
        setupWebView()
    }

    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let customCSS = """
        html, body {
            -webkit-user-select: text;
            -webkit-touch-callout: default;
            touch-action: manipulation;
            background-color: transparent !important;
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
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"

        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // НАСТРОЙКА ГЕОМЕТРИИ:
        // topAnchor привязан к безопасной зоне статус-бара + 8 поинтов (суммарно ~1 см на 6S Plus)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        webView.load(URLRequest(url: targetURL))
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - Главный интерфейс
struct ContentView: View {
    private let targetURL = URL(string: "https://gemini.google.com")!

    var body: some View {
        UltraWebViewControllerRepresentable(url: targetURL)
            // Игнорируем только нижний край, чтобы сайт доходил до самого низа экрана
            .ignoresSafeArea(.all, edges: .bottom)
    }
}