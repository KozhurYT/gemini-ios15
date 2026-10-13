import SwiftUI
import WebKit

// MARK: - Модель сообщения
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

// MARK: - Менеджер скрытого WebView и JavaScript-моста
class GeminiBridge: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    @Published var messages: [ChatMessage] = []
    @Published var isGenerating: Bool = false
    @Published var isPageLoaded: Bool = false

    var webView: WKWebView!

    override init() {
        super.init()
        setupWebView()
    }

    private func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "geminiBridge")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"

        if let url = URL(string: "https://gemini.google.com") {
            webView.load(URLRequest(url: url))
        }
    }

    // Внедрение JavaScript для слежения за ответами
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isPageLoaded = true
        injectObserverScript()
    }

    private func injectObserverScript() {
        let script = """
        (function() {
            if (window._geminiObserverAttached) return;
            window._geminiObserverAttached = true;

            const observer = new MutationObserver(() => {
                // Ищем блоки с текстом ответа модели
                const responses = document.querySelectorAll('message-content, .model-response-text, [data-test-id="model-response"]');
                if (responses.length > 0) {
                    const lastResponse = responses[responses.length - 1];
                    const text = lastResponse.innerText || lastResponse.textContent;
                    if (text && text.trim().length > 0) {
                        window.webkit.messageHandlers.geminiBridge.postMessage({
                            type: 'chunk',
                            text: text
                        });
                    }
                }
            });

            observer.observe(document.body, { childList: true, subtree: true, characterData: true });
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    // Отправка сообщения в скрытый сайт через JS
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Добавляем сообщение пользователя в нативный UI
        messages.append(ChatMessage(text: text, isUser: true))
        isGenerating = true

        // Создаем пустую заглушку под ответ Gemini
        messages.append(ChatMessage(text: "Печатает...", isUser: false))

        let escapedText = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        let sendScript = """
        (function() {
            // Поиск поля ввода (rich-textarea или contenteditable)
            let editor = document.querySelector('rich-textarea p') || document.querySelector('[contenteditable="true"]');
            if (editor) {
                editor.innerText = "\(escapedText)";
                editor.dispatchEvent(new Event('input', { bubbles: true }));

                setTimeout(() => {
                    let sendBtn = document.querySelector('button[aria-label*="Send"]') || 
                                  document.querySelector('button[aria-label*="Отправить"]') || 
                                  document.querySelector('.send-button') ||
                                  document.querySelector('button.mat-mdc-tooltip-trigger');
                    if (sendBtn) {
                        sendBtn.click();
                    }
                }, 300);
            }
        })();
        """

        webView.evaluateJavaScript(sendScript, completionHandler: nil)
    }

    // Обработка входящих данных из JavaScript
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "geminiBridge",
           let dict = message.body as? [String: Any],
           let text = dict["text"] as? String {

            DispatchQueue.main.async {
                // Обновляем последнее сообщение от бота
                if let lastIndex = self.messages.indices.last, !self.messages[lastIndex].isUser {
                    self.messages[lastIndex] = ChatMessage(text: text, isUser: false)
                }
                self.isGenerating = false
            }
        }
    }
}

// MARK: - Представление WebView для SwiftUI
struct BridgeWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Главный интерфейс (Нативный Чат + Переключатель)
struct ContentView: View {
    @StateObject private var bridge = GeminiBridge()
    @State private var inputText = ""
    @State private var showBrowser = false // Переключатель: нативный UI или окно браузера

    var body: some View {
        NavigationView {
            ZStack {
                if showBrowser {
                    // Режим браузера: для первого логина и проверки
                    BridgeWebViewRepresentable(webView: bridge.webView)
                        .ignoresSafeArea(.all, edges: .bottom)
                } else {
                    // Режим полноценного нативного чата
                    VStack(spacing: 0) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    if bridge.messages.isEmpty {
                                        VStack(spacing: 8) {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 40))
                                                .foregroundColor(.blue)
                                            Text("Gemini Native")
                                                .font(.headline)
                                            Text("Если это первый запуск, нажми значок браузера вверху справа и войди в Google-аккаунт.")
                                                .font(.caption)
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(.gray)
                                                .padding(.horizontal, 40)
                                        }
                                        .padding(.top, 60)
                                    }

                                    ForEach(bridge.messages) { msg in
                                        HStack {
                                            if msg.isUser { Spacer() }
                                            
                                            Text(msg.text)
                                                .padding(12)
                                                .background(msg.isUser ? Color.blue : Color(UIColor.secondarySystemBackground))
                                                .foregroundColor(msg.isUser ? .white : .primary)
                                                .cornerRadius(16)
                                                .frame(maxWidth: 280, alignment: msg.isUser ? .trailing : .leading)

                                            if !msg.isUser { Spacer() }
                                        }
                                        .padding(.horizontal)
                                        .id(msg.id)
                                    }
                                }
                                .padding(.vertical)
                            }
                            .onChange(of: bridge.messages) { _ in
                                if let last = bridge.messages.last {
                                    withAnimation {
                                        proxy.scrollTo(last.id, anchor: .bottom)
                                    }
                                }
                            }
                        }

                        Divider()

                        // Нативная строка ввода
                        HStack(spacing: 8) {
                            TextField("Спроси у Gemini...", text: $inputText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            Button(action: {
                                bridge.sendMessage(inputText)
                                inputText = ""
                            }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(inputText.isEmpty ? .gray : .blue)
                            }
                            .disabled(inputText.isEmpty || bridge.isGenerating)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemBackground))
                    }
                }
            }
            .navigationTitle(showBrowser ? "Браузер (Логин)" : "Gemini")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showBrowser.toggle() }) {
                        Image(systemName: showBrowser ? "message" : "safari")
                    }
                }
            }
        }
    }
}