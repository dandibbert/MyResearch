import SwiftUI
import WebKit

struct ExtensionBrowser: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var failure: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let failure {
                    VStack(spacing: 10) {
                        Text(failure).font(.footnote).multilineTextAlignment(.center)
                        Button("复制链接") { UIPasteboard.general.string = url.absoluteString }
                    }.padding().frame(maxWidth: .infinity)
                }
                ExtensionWebView(url: url) { failure = $0 }
            }
            .navigationTitle(url.host ?? "搜索结果").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

struct ExtensionWebView: UIViewRepresentable {
    let url: URL
    var failed: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(failed: failed) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.load(URLRequest(url: url))
        return web
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKNavigationDelegate {
        let failed: (String) -> Void
        init(failed: @escaping (String) -> Void) { self.failed = failed }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { failed("网页加载失败：\(error.localizedDescription)") }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { failed("网页加载失败：\(error.localizedDescription)") }
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let scheme = action.request.url?.scheme?.lowercased() else { decisionHandler(.cancel); return }
            if ["http", "https", "about"].contains(scheme) { decisionHandler(.allow) }
            else { decisionHandler(.cancel); failed("此页面尝试打开外部 App。扩展中不强制跳转，可复制搜索链接后在主 App 中打开。") }
        }
    }
}
