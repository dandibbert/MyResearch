import SwiftUI
import WebKit

struct ExtensionBrowser: View {
    let url: URL
    var openExternal: ((URL) async -> Bool)? = nil
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
                ExtensionWebView(url: url, failed: { failure = $0 }, openExternal: openExternal)
            }
            .navigationTitle(url.host ?? "搜索结果").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

struct ExtensionWebView: UIViewRepresentable {
    let url: URL
    var failed: (String) -> Void
    var openExternal: ((URL) async -> Bool)?
    func makeCoordinator() -> Coordinator { Coordinator(failed: failed, openExternal: openExternal) }
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
        let openExternal: ((URL) async -> Bool)?
        init(failed: @escaping (String) -> Void, openExternal: ((URL) async -> Bool)?) { self.failed = failed; self.openExternal = openExternal }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { failed("网页加载失败：\(error.localizedDescription)") }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { failed("网页加载失败：\(error.localizedDescription)") }
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let scheme = action.request.url?.scheme?.lowercased() else { decisionHandler(.cancel); return }
            if ["http", "https", "about"].contains(scheme) { decisionHandler(.allow) }
            else {
                decisionHandler(.cancel)
                guard action.navigationType == .linkActivated,
                      let url = action.request.url,
                      !["javascript", "data", "file", "myresearch"].contains(scheme),
                      let openExternal else { return }
                Task { @MainActor in
                    if !(await openExternal(url)) { failed("系统没有确认打开外部 App。可返回来源列表或复制搜索链接。") }
                }
            }
        }
    }
}
