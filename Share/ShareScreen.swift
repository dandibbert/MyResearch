import SwiftUI
import UniformTypeIdentifiers

struct ShareScreen: View {
    @ObservedObject var model: ShareModel
    @StateObject private var suggestions = SuggestionsModel()
    @State private var focused = false
    @State private var importing = false
    @State private var pendingImport: Configuration?
    @State private var confirmImport = false
    @State private var showHelp = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: model.synchronized ? "checkmark.circle.fill" : "link")
                    Text(model.synchronization).lineLimit(1)
                    Spacer(minLength: 0)
                    if model.loading || model.opening { ProgressView().controlSize(.small) }
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 6)
                if !model.synchronized {
                    Button { model.continueInApp() } label: {
                        Label("在主 App 中选择我的来源", systemImage: "arrow.up.forward.app")
                            .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                    }.accessibilityIdentifier("share-handoff").padding(.horizontal, 12)
                }
                if !model.notice.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.notice).font(.caption).foregroundStyle(.secondary)
                        if model.failedURL != nil {
                            HStack {
                                if let url = model.failedWebURL { Button("网页搜索") { model.browser = BrowserDestination(url: url) } }
                                Button("转到主 App") { model.continueInApp() }
                                Button("复制链接") { UIPasteboard.general.string = model.failedURL?.absoluteString }
                            }.font(.caption).buttonStyle(.bordered)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 6)
                        .accessibilityIdentifier("share-notice")
                }
                GeometryReader { geometry in
                    VStack(spacing: 6) {
                        sources.frame(height: max(0, min(270, geometry.size.height * 0.62)))
                        candidates.frame(maxHeight: .infinity)
                    }
                }.padding(.horizontal, 12).clipped()
                if !model.intent.query.isEmpty {
                    ShareCandidateRow(query: model.intent.query, targets: model.configuration.quickTargets, original: true,
                                      search: { model.search(model.intent.query, target: $0 ?? model.currentTarget) }, fill: nil)
                        .disabled(model.opening || model.loading).padding(.horizontal, 12).padding(.top, 6)
                }
                HStack(spacing: 4) {
                    Image(systemName: model.intent.targetID == nil ? "magnifyingglass" : "bolt.fill")
                        .foregroundStyle(ResearchStyle.accent).padding(.leading, 12)
                    SearchField(text: Binding(get: { model.query }, set: { model.loading = false; model.query = $0 }), focused: $focused, identifier: "share-input") {
                        model.search(model.intent.query, target: model.currentTarget)
                    }.frame(height: 48)
                    if focused {
                        Button { focused = false } label: { Image(systemName: "keyboard.chevron.compact.down").frame(width: 44, height: 44) }
                            .accessibilityLabel("收起键盘")
                    }
                    Button { model.search(model.intent.query, target: model.currentTarget) } label: {
                        Image(systemName: "arrow.up").font(.body.bold()).foregroundStyle(.white).frame(width: 44, height: 44)
                            .background(ResearchStyle.accent, in: RoundedRectangle(cornerRadius: 12))
                    }.disabled(model.opening || model.loading).accessibilityIdentifier("share-submit").accessibilityLabel("搜索").padding(.trailing, 4)
                }.background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 8)
            }
            .background(ResearchStyle.background)
            .navigationTitle("快速搜索").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button("在主 App 继续", systemImage: "arrow.up.forward.app") { model.continueInApp() }
                        Button("复制文字", systemImage: "doc.on.doc") { UIPasteboard.general.string = model.intent.query }
                        Button("重新读取主 App 配置", systemImage: "arrow.clockwise") { model.reloadConfiguration() }
                        Button("导入配置 JSON", systemImage: "square.and.arrow.down") { importing = true }
                        Toggle("兼容跳转（自签版）", isOn: $model.compatibility)
                        Button("说明与共享状态", systemImage: "info.circle") { showHelp = true }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                    .accessibilityIdentifier("share-more")
                }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { model.done?() }.accessibilityIdentifier("share-done") }
            }
            .sheet(item: $model.browser) { value in
                ExtensionBrowser(url: value.url, openExternal: { url in
                    guard let open = model.openURL else { return false }
                    return await open(url, model.compatibility)
                })
            }
            .sheet(isPresented: $showHelp) {
                NavigationStack {
                    List {
                        Text("点来源或原词右侧按钮：优先跳到目标 App／系统浏览器。长按来源可以只在扩展内搜索网页或复制链接。")
                        Text("\(model.synchronization)。共享钥匙串可用时，主 App 的排序、启停、默认来源、Trigger 与联想设置自动复用；否则可接力到主 App，不必重新输入。")
                        Text("兼容跳转使用现代系统打开方法，但不是 Apple 对分享扩展保证的能力。系统版本、宿主 App 或重签方式可能阻止它；失败不会显示成已完成。")
                        Text("联想遵循主 App 设置；开启 Bing/Google 时关键词会发送给对应提供方。这里不读取主 App 搜索历史。")
                    }.navigationTitle("快速搜索说明").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showHelp = false } } }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 2_000_000 { throw ResearchError("配置文件不能超过 2 MB。") }
                    pendingImport = try ConfigurationCodec.decode(Data(contentsOf: url))
                    confirmImport = true
                } catch { model.error = error.localizedDescription }
            }
            .confirmationDialog("使用导入的 \(pendingImport?.targets.count ?? 0) 个来源？", isPresented: $confirmImport, titleVisibility: .visible) {
                Button("仅替换扩展配置") {
                    do { if let value = pendingImport { try model.importConfiguration(value) } }
                    catch { model.error = error.localizedDescription }
                    pendingImport = nil
                }
            } message: { Text("不会修改主 App。下次成功读取共享配置时，会重新以主 App 为准。") }
            .alert("提示", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("好", role: .cancel) { model.error = nil }
            } message: { Text(model.error ?? "") }
            .onAppear { refresh() }
            .onChange(of: model.query) { refresh() }
            .onChange(of: model.configuration) { refresh() }
            .onDisappear { suggestions.cancel() }
        }
    }
    private var sources: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.intent.targetID == nil ? "搜索到" : "闪电 · \(model.currentTarget?.name ?? "")")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 4)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.configuration.enabledTargets) { target in
                        Button { model.search(model.intent.query, target: target) } label: { SourceRow(target: target) }
                            .buttonStyle(.plain).accessibilityIdentifier("share-target-\(target.id)")
                            .disabled(model.opening || model.loading || (model.intent.query.isEmpty && !target.isAction))
                            .contextMenu {
                                Button("打开 App／系统浏览器") { model.search(model.intent.query, target: target) }
                                Button("在扩展内搜索网页") { model.browse(model.intent.query, target: target) }
                                Button("复制搜索链接") {
                                    do { UIPasteboard.general.string = try TemplateEngine.url(template: target.template, query: model.intent.query).absoluteString }
                                    catch { model.error = error.localizedDescription }
                                }
                            }
                        if target.id != model.configuration.enabledTargets.last?.id { Divider().padding(.leading, 46) }
                    }
                    if model.configuration.enabledTargets.isEmpty { Text("没有启用的来源，请在主 App 中添加。").font(.subheadline).padding() }
                }.padding(.horizontal, 12)
            }.scrollDismissesKeyboard(.never).background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    private var candidates: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("联想 · \(suggestions.status)").font(.caption).foregroundStyle(.secondary)
                Spacer(); if suggestions.loading { ProgressView().controlSize(.mini) }
            }.padding(.horizontal, 4).frame(height: 22)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(suggestions.values, id: \.self) { word in
                        ShareCandidateRow(query: word, targets: model.configuration.quickTargets, original: false,
                            search: { model.search(word, target: $0 ?? model.currentTarget) },
                            fill: { model.query = word; focused = true })
                    }
                    if suggestions.values.isEmpty { Text("原词固定在下方，点一下就能搜索。")
                        .font(.caption).foregroundStyle(.tertiary).padding(.vertical, 12) }
                }
            }.scrollDismissesKeyboard(.never)
        }
    }
    private func refresh() {
        suggestions.refresh(query: model.intent.query, settings: model.configuration.settings, history: [], testMode: false)
    }
}

private struct ShareCandidateRow: View {
    var query: String
    var targets: [SearchTarget]
    var original: Bool
    var search: (SearchTarget?) -> Void
    var fill: (() -> Void)?
    var body: some View {
        HStack(spacing: 0) {
            Button { search(nil) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    if original { Text("原词").font(.system(size: 10, weight: .semibold)).foregroundStyle(ResearchStyle.accent) }
                    Text(query).font(.subheadline.weight(original ? .semibold : .regular)).foregroundStyle(.primary).lineLimit(1)
                }.frame(maxWidth: .infinity, minHeight: original ? 58 : 48, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier(original ? "share-original" : "share-candidate-\(query)")
            if let fill { Button(action: fill) { Image(systemName: "arrow.up.left").font(.caption).frame(width: 44, height: 44) }.accessibilityLabel("填入\(query)") }
            ForEach(targets) { target in
                Button { search(target) } label: { TargetIcon(target: target, size: 29).frame(width: 44, height: 44).contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("用\(target.name)搜索\(query)")
                    .accessibilityIdentifier("share-quick-\(target.id)")
            }
        }.padding(.leading, 12).padding(.trailing, 4)
            .background(original ? ResearchStyle.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 16))
    }
}
