import SwiftUI

struct LinksScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var editing: SearchTarget?
    @State private var showPresets = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.configuration.targets) { target in
                        HStack(spacing: 8) {
                            Button { editing = target } label: {
                                SourceRow(target: target, detail: target.isAction ? "固定动作" : (target.quickAccess ? "候选快捷来源" : nil))
                            }.buttonStyle(.plain).accessibilityIdentifier("edit-\(target.id)")
                            Toggle("启用\(target.name)", isOn: Binding(get: { target.enabled }, set: { store.setEnabled($0, id: target.id) }))
                                .labelsHidden().scaleEffect(0.85).fixedSize()
                        }
                    }
                    .onMove { store.move(from: $0, to: $1) }
                    .onDelete { store.delete(at: $0) }
                } header: { Text("\(store.configuration.targets.count) 个链接") }
                  footer: { Text("点链接编辑。点「编辑」后拖拽排序；首页与候选右侧快捷按钮遵循此顺序，不自动重排。") }
                if store.configuration.targets.isEmpty {
                    Button("添加预设来源") { showPresets = true }
                }
            }
            .scrollContentBackground(.hidden).background(ResearchStyle.background)
            .navigationTitle("我的链接")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("从预设添加", systemImage: "square.grid.2x2") { showPresets = true }
                        Button("自定义链接", systemImage: "plus") { editing = SearchTarget() }
                    } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                        .accessibilityLabel("添加链接").accessibilityIdentifier("add-link")
                }
            }
            .sheet(item: $editing) { target in TargetEditor(target: target).environmentObject(store) }
            .sheet(isPresented: $showPresets) { PresetPicker().environmentObject(store) }
        }
    }
}

struct PresetPicker: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Presets.all) { target in
                        let exists = store.configuration.targets.contains { $0.id == target.id }
                        Button {
                            do { try store.upsert(target) } catch { self.error = error.localizedDescription }
                        } label: {
                            HStack {
                                SourceRow(target: target)
                                Image(systemName: exists ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundStyle(exists ? Color.secondary : ResearchStyle.accent)
                            }
                        }.buttonStyle(.plain).disabled(exists)
                    }
                } footer: { Text("预设使用可编辑网页链接。能否自动打开原生 App 由系统和目标应用决定；部分服务需要登录。") }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("添加预设").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

struct TargetEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SearchTarget
    @State private var aliasText: String
    @State private var testQuery = "春莱布"
    @State private var saveError: String?
    private let symbols = ["magnifyingglass", "globe", "play.rectangle.fill", "book.closed.fill", "bag.fill", "map.fill", "text.bubble.fill", "bolt.fill", "star.fill", "heart.fill", "terminal.fill", "link"]
    private let colors = ["5265DE", "4285F4", "EB4B65", "E777A0", "148C95", "479E64", "EB7D32", "657083"]

    init(target: SearchTarget) {
        _draft = State(initialValue: target)
        _aliasText = State(initialValue: target.aliases.joined(separator: ", "))
    }
    private var prepared: SearchTarget {
        var value = draft
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.template = value.template.trimmingCharacters(in: .whitespacesAndNewlines)
        value.fallbackTemplate = value.fallbackTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        value.aliases = aliasText.split { $0.isWhitespace || $0 == "," || $0 == "，" || $0 == "、" }.map(String.init)
        return value
    }
    private var validation: String? {
        var config = store.configuration
        if let index = config.targets.firstIndex(where: { $0.id == draft.id }) { config.targets[index] = prepared }
        else { config.targets.append(prepared) }
        do { try ConfigurationCodec.validate(config); return nil } catch { return error.localizedDescription }
    }
    private var preview: Result<URL, Error> { Result { try TemplateEngine.url(template: prepared.template, query: testQuery) } }

    var body: some View {
        NavigationStack {
            Form {
                Section("显示") {
                    HStack { TargetIcon(target: draft, size: 40); TextField("链接名称", text: $draft.name).accessibilityIdentifier("target-name") }
                    Picker("图标", selection: $draft.symbol) {
                        ForEach(Array(Set(symbols + [draft.symbol])).sorted(), id: \.self) { symbol in Label(symbol, systemImage: symbol).tag(symbol) }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(colors, id: \.self) { color in
                                Button { draft.tintHex = color } label: {
                                    Circle().fill(Color(hex: color)).frame(width: 25, height: 25)
                                        .overlay { if draft.tintHex == color { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } }
                                        .frame(width: 44, height: 44)
                                }.buttonStyle(.plain).accessibilityLabel("颜色 \(color)")
                            }
                        }
                    }
                }
                Section {
                    TextField("https://example.com/search?q={query}", text: $draft.template, axis: .vertical)
                        .font(.system(.subheadline, design: .monospaced)).lineLimit(2...5)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("target-template")
                    Button("插入 {query}") { draft.template += "{query}" }
                    if prepared.isAction { Label("固定动作：此链接不携带搜索词", systemImage: "bolt").font(.caption).foregroundStyle(.secondary) }
                } header: { Text("搜索链接") }
                  footer: { Text("把 {query} 放在搜索词的位置；支持多个占位符，中文和特殊符号会自动编码。") }
                Section {
                    TextField("可选：https://example.com/?q={query}", text: $draft.fallbackTemplate, axis: .vertical)
                        .font(.system(.subheadline, design: .monospaced)).lineLimit(1...4)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: { Text("打开失败时的网页兜底") }
                  footer: { Text("仅在系统无法打开主链接时尝试一次；不会检测目标 App 内部是否支持此搜索页。") }
                Section {
                    TextField("例如：b, bili", text: $aliasText).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("target-aliases")
                } header: { Text("Trigger Word") }
                  footer: { Text("用逗号分隔多个触发词。支持「b 春莱布」或「春莱布 b」；按键盘搜索提交，不会在打字中途跳走。") }
                Section("使用方式") {
                    Toggle("启用链接", isOn: $draft.enabled)
                    Toggle("显示在候选右侧", isOn: $draft.quickAccess)
                    Text("只展示排序最前的三个已启用快捷来源。其他来源仍可从首页列表使用。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("实时测试") {
                    TextField("测试关键词", text: $testQuery)
                    switch preview {
                    case .success(let url):
                        Text(url.absoluteString).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        Button("测试打开", systemImage: "arrow.up.right.square") { store.search(testQuery, target: prepared, recordHistory: false) }
                    case .failure(let error): Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
                    }
                }
                if let message = validation ?? saveError {
                    Section { Text(message).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("编辑链接").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try store.upsert(prepared); dismiss() } catch { saveError = error.localizedDescription }
                    }.disabled(validation != nil).accessibilityIdentifier("save-target")
                }
            }
        }
    }
}
