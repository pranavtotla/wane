#if canImport(SwiftUI) && canImport(WebKit) && canImport(AppKit)
import SwiftUI
import WebKit
import AppKit

struct CursorLoginView: View {
    @Binding var isPresented: Bool
    var onSuccess: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sign in to Cursor")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            CursorWebView(onCookieCaptured: { cookieHeader in
                onSuccess(cookieHeader)
                isPresented = false
            })
        }
        .frame(width: 420, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, .dark)
    }
}

struct CursorWebView: NSViewRepresentable {
    let onCookieCaptured: (String) -> Void

    private static let sessionCookieNames: Set<String> = [
        "WorkosCursorSessionToken",
        "__Secure-next-auth.session-token",
        "next-auth.session-token",
    ]

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        let url = URL(string: "https://cursor.com/dashboard")!
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCookieCaptured: onCookieCaptured)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onCookieCaptured: (String) -> Void
        private var hasCapture = false

        init(onCookieCaptured: @escaping (String) -> Void) {
            self.onCookieCaptured = onCookieCaptured
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkCookies(in: webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            checkCookies(in: webView)
            return .allow
        }

        private func checkCookies(in webView: WKWebView) {
            guard !hasCapture else { return }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.hasCapture else { return }

                let cursorCookies = cookies.filter {
                    ($0.domain.hasSuffix("cursor.com") || $0.domain.hasSuffix("cursor.sh"))
                    && CursorWebView.sessionCookieNames.contains($0.name)
                }

                guard !cursorCookies.isEmpty else { return }

                let header = cursorCookies
                    .map { "\($0.name)=\($0.value)" }
                    .joined(separator: "; ")

                self.hasCapture = true
                DispatchQueue.main.async {
                    self.onCookieCaptured(header)
                }
            }
        }
    }
}
#endif
