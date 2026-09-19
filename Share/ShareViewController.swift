import UIKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ShareModel: ObservableObject {
    @Published var query = ""
    @Published var configuration = Configuration.initial
    @Published var error: String?
    init() {
        if let data = UserDefaults.standard.data(forKey: "share-configuration"), let decoded = try? ConfigurationCodec.decode(data) { configuration = decoded }
    }
    func importConfiguration(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 2_000_000 { throw ResearchError("配置文件不能超过 2 MB。") }
        let value = try ConfigurationCodec.decode(Data(contentsOf: url))
        UserDefaults.standard.set(try ConfigurationCodec.encode(value), forKey: "share-configuration")
        configuration = value
    }
}

final class ShareViewController: UIViewController {
    private let model = ShareModel()
    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareScreen(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }.tint(ResearchStyle.accent))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        loadText()
    }
    private func loadText() {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        for type in [UTType.plainText.identifier, UTType.url.identifier] {
            if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type) }) {
                provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, error in
                    let text: String?
                    if let string = item as? String { text = string }
                    else if let url = item as? URL { text = url.absoluteString }
                    else if let data = item as? Data { text = String(data: data, encoding: .utf8) }
                    else { text = nil }
                    Task { @MainActor in
                        self?.model.query = String((text ?? "").prefix(4096))
                        if text == nil { self?.model.error = error?.localizedDescription ?? "没有读取到文字，可以手动输入。" }
                    }
                }
                return
            }
        }
        model.query = String((items.first?.attributedContentText?.string ?? "").prefix(4096))
    }
}

struct BrowserDestination: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareScreen: View {
    @ObservedObject var model: ShareModel
    var done: () -> Void
    @State private var importing = false
    @State private var browser: BrowserDestination?
    @State private var lastURL: URL?
    var body: some View {
        NavigationStack {
            List {
                Section("搜索内容") {
                    TextField("输入关键词", text: $model.query, axis: .vertical).lineLimit(2...5)
                }
                Section {
                    ForEach(model.configuration.enabledTargets) { target in
                        Button { open(target) } label: { SourceRow(target: target) }.buttonStyle(.plain)
                    }
                } header: { Text("网页快速搜索") }
                  footer: { Text("扩展内搜索，不强行启动其他 App。来源使用独立预设，可导入主 App 导出的配置。") }
                Section {
                    Button("导入配置 JSON") { importing = true }
                    if let lastURL {
                        Button("复制搜索链接") { UIPasteboard.general.string = lastURL.absoluteString }
                        Text(lastURL.absoluteString).font(.caption).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("MyResearch").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", action: done) } }
            .sheet(item: $browser) { value in ExtensionBrowser(url: value.url) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do { try model.importConfiguration(result.get()) } catch { model.error = error.localizedDescription }
            }
            .alert("提示", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("好", role: .cancel) { model.error = nil }
            } message: { Text(model.error ?? "") }
        }
    }
    private func open(_ target: SearchTarget) {
        do {
            let intent = SearchRouter.intent(for: model.query, configuration: model.configuration)
            let primary = try TemplateEngine.url(template: target.template, query: intent.query)
            lastURL = primary
            if ["https", "http"].contains(primary.scheme?.lowercased() ?? "") { browser = BrowserDestination(url: primary) }
            else if !target.fallbackTemplate.isEmpty {
                browser = BrowserDestination(url: try TemplateEngine.url(template: target.fallbackTemplate, query: intent.query))
            } else { model.error = "此链接只能在主 App 中跳转。可复制搜索链接；或为来源配置 HTTPS 网页兜底。" }
        } catch { model.error = error.localizedDescription }
    }
}
