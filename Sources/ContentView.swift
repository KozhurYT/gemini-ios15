import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    let url: URL
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    let webView: WKWebView

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"

        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewContainer

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}

struct ContentView: View {
    private let targetURL = URL(string: "https://gemini.google.com")!
    private let webView = WKWebView()

    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 2)
            } else {
                Spacer().frame(height: 2)
            }

            WebViewContainer(
                url: targetURL,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                isLoading: $isLoading,
                webView: webView
            )

            Divider()

            HStack {
                Button(action: { webView.goBack() }) {
                    Image(systemName: "chevron.left").font(.title3)
                }
                .disabled(!canGoBack)

                Spacer()

                Button(action: { webView.goForward() }) {
                    Image(systemName: "chevron.right").font(.title3)
                }
                .disabled(!canGoForward)

                Spacer()

                Button(action: { webView.reload() }) {
                    Image(systemName: "arrow.clockwise").font(.title3)
                }

                Spacer()

                Button(action: { webView.load(URLRequest(url: targetURL)) }) {
                    Image(systemName: "house").font(.title3)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 10)
            .padding(.bottom, 5)
            .foregroundColor(.primary)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}