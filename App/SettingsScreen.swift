import SwiftUI
import UniformTypeIdentifiers

struct ConfigurationFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw ResearchError("无法读取文件。") }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDocument: ConfigurationFile?
    @State private var pendingImport: Configuration?
    @State private var confirmImport = false
    @State private var confirmClear = false
    @State private var help = false

    private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { store.configuration.settings[keyPath: keyPath] }, set: { value in store.updateSettings { $0[keyPath: keyPath] = value } })
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("自动弹出键盘", isOn: setting(\.autoFocus))
                    Toggle("跟手布局", isOn: setting(\.thumbLayout))
                    Toggle("闪电模式 · Trigger", isOn: setting(\.lightning))
                    Picker("默认搜索", selection: Binding(get: { store.configuration.defaultTarget?.id ?? "" }, set: { id in store.updateSettings { $0.defaultTargetID = id } })) {
                        if store.configuration.enabledTargets.isEmpty { Text("无启用来源").tag("") }
                        ForEach(store.configuration.enabledTargets) { target in Text(target.name).tag(target.id) }
                    }
                } header: { Text("搜索体验") }
                  footer: { Text("跟手布局把输入框和固定原词行放在键盘上方。来源顺序在「我的链接」手动调整。") }
                Section {
                    Picker("联想来源", selection: setting(\.provider)) {
                        ForEach(SuggestionProvider.allCases) { provider in Text(provider.title).tag(provider) }
                    }
                    Stepper("最多 \(store.configuration.settings.maxSuggestions) 条联想", value: setting(\.maxSuggestions), in: 1...12)
                } header: { Text("搜索联想") }
                  footer: { Text("选择 Bing 或 Google 后，已提交的关键词会发送至该第三方以获取联想。服务不可用时仍能搜索原词；选择本地或关闭即可停止联网联想。") }
                Section {
                    Toggle("记录搜索历史", isOn: setting(\.historyEnabled))
                    Button("清空 \(store.history.count) 条历史", role: .destructive) { confirmClear = true }
                } header: { Text("隐私") }
                  footer: { Text("历史仅保存在本机。关闭后停止记录与展示，已有数据可单独清空。不自动读取剪贴板，无遥测或自建服务器。") }
                Section {
                    Button("导出链接与设置", systemImage: "square.and.arrow.up") {
                        do { exportDocument = ConfigurationFile(data: try ConfigurationCodec.encode(store.configuration)); exporting = true }
                        catch { store.errorMessage = error.localizedDescription }
                    }
                    Button("导入配置 JSON", systemImage: "square.and.arrow.down") { importing = true }
                } header: { Text("备份与迁移") }
                  footer: { Text("导出不含搜索历史。导入前会验证并确认替换，替换前在本机自动保留旧配置备份。无需 iCloud 或 App Groups。") }
                Section("快速搜索") {
                    Button("分享扩展与安装说明", systemImage: "square.and.arrow.up.on.square") { help = true }
                    Text("快捷指令可使用 myresearch://search?q=关键词 打开搜索页；附加 &target=google&run=1 可立即搜索。")
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Section {
                    LabeledContent("MyResearch", value: "1.0.0")
                    Text("打开就输入。原词始终在手边。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: "MyResearch-links") { result in
                if case .failure(let error) = result { store.errorMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 2_000_000 { throw ResearchError("配置文件不能超过 2 MB。") }
                    pendingImport = try ConfigurationCodec.decode(Data(contentsOf: url))
                    confirmImport = true
                } catch { store.errorMessage = error.localizedDescription }
            }
            .confirmationDialog("替换当前链接与设置？", isPresented: $confirmImport, titleVisibility: .visible) {
                Button("替换为 \(pendingImport?.targets.count ?? 0) 个链接", role: .destructive) {
                    guard let pendingImport else { return }
                    do { try store.replaceConfiguration(pendingImport); self.pendingImport = nil }
                    catch { store.errorMessage = error.localizedDescription }
                }
                Button("取消", role: .cancel) { pendingImport = nil }
            } message: { Text("将替换当前 \(store.configuration.targets.count) 个链接及设置。历史不受影响。") }
            .confirmationDialog("清空搜索历史？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清空历史", role: .destructive) { store.clearHistory() }
            }
            .sheet(isPresented: $help) { ExtensionHelp() }
        }
    }
}

struct ExtensionHelp: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("完整包") {
                    Text("在支持分享文字或网页地址的 App 中，打开分享菜单并选择 MyResearch。选择来源后，在扩展里进行网页搜索。")
                    Text("扩展使用独立预设；自定义来源可先从主 App 导出 JSON，再在扩展的「导入配置」中载入。当前版本不自动同步两者配置。")
                }
                Section("安装方式") {
                    Text("未签名 IPA 需要你的签名工具处理后安装。完整包必须同时签名主 App 和扩展；不需要扩展时可选择 core 包。")
                    Text("LiveContainer 等容器式运行方式不保证系统注册分享扩展。主 App 的搜索功能不依赖扩展、iCloud 或 App Groups。")
                }
                Section("边界") {
                    Text("扩展内网页搜索与主 App 原生跳转不是同一种行为。未使用私有 API 绕过 iOS 的扩展限制；部分网页可能要求登录或不支持嵌入式浏览。")
                }
            }.navigationTitle("快速搜索").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
