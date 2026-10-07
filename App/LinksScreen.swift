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
                                SourceRow(
                                    target: target,
                                    detail: target.kind == .translator
                                        ? target.translatorDetail
                                        : (target.isAction ? "固定动作" : (target.usesInAppSafari ? "App 内 Safari" : nil))
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("edit-\(target.id)")
                            Toggle("启用\(target.name)", isOn: Binding(
                                get: { target.enabled },
                                set: { store.setEnabled($0, id: target.id) }
                            ))
                            .labelsHidden().scaleEffect(0.85).fixedSize()
                        }
                    }
                    .onMove { store.move(from: $0, to: $1) }
                    .onDelete { store.delete(at: $0) }
                } header: {
                    Text("\(store.configuration.targets.count) 个来源")
                } footer: {
                    Text("搜索链接和翻译引擎共用同一套顺序、启停与 Trigger。首页快捷按钮也遵循这里的手动顺序。")
                }

                if store.configuration.targets.isEmpty {
                    Button("添加预设来源") { showPresets = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ResearchStyle.background)
            .navigationTitle("我的来源")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("从预设添加", systemImage: "square.grid.2x2") { showPresets = true }
                        Button("自定义搜索链接", systemImage: "link.badge.plus") { editing = SearchTarget() }
                        Button("翻译引擎", systemImage: "character.book.closed") {
                            let id = UUID().uuidString
                            editing = SearchTarget(
                                id: id,
                                name: "翻译",
                                symbol: "character.book.closed.fill",
                                tintHex: "5265DE",
                                template: "",
                                kind: .translator,
                                translator: TranslationConfiguration(
                                    credentialID: "translator.\(id)"
                                )
                            )
                        }
                    } label: {
                        Image(systemName: "plus").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("添加来源")
                    .accessibilityIdentifier("add-link")
                }
            }
            .sheet(item: $editing) { target in
                TargetEditor(target: target).environmentObject(store)
            }
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
                        }
                        .buttonStyle(.plain)
                        .disabled(exists)
                    }
                } footer: {
                    Text("预设均为可编辑搜索链接；翻译引擎请从右上角「+」单独添加。")
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("添加预设")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
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

    @State private var translatorDraft: TranslationConfiguration
    @State private var httpHeadersText: String
    @State private var apiKey = ""
    @State private var credentialPresent: Bool

    @State private var templateSelection: NSRange
    @State private var httpURLSelection: NSRange
    @State private var httpHeadersSelection: NSRange
    @State private var bodySelection: NSRange
    @State private var promptSelection: NSRange

    private let symbols = [
        "magnifyingglass", "globe", "play.rectangle.fill", "book.closed.fill",
        "character.book.closed.fill", "bag.fill", "map.fill", "text.bubble.fill",
        "bolt.fill", "star.fill", "heart.fill", "terminal.fill", "link"
    ]
    private let colors = ["5265DE", "4285F4", "EB4B65", "E777A0", "148C95", "479E64", "EB7D32", "657083"]

    init(target: SearchTarget) {
        let translator = target.translator ?? .openAIDefault
        let http = translator.http ?? HTTPTranslationConfiguration()
        let prompt = translator.openAI?.systemPrompt ?? OpenAIChatConfiguration().systemPrompt

        _draft = State(initialValue: target)
        _aliasText = State(initialValue: target.aliases.joined(separator: ", "))
        _translatorDraft = State(initialValue: translator)
        _httpHeadersText = State(initialValue: Self.encodeHeaders(http.headers))
        _credentialPresent = State(initialValue: translator.credentialID.map(SharedCredentialStore.contains) ?? false)

        _templateSelection = State(initialValue: NSRange(location: (target.template as NSString).length, length: 0))
        _httpURLSelection = State(initialValue: NSRange(location: (http.url as NSString).length, length: 0))
        _httpHeadersSelection = State(initialValue: NSRange(location: (Self.encodeHeaders(http.headers) as NSString).length, length: 0))
        _bodySelection = State(initialValue: NSRange(location: (http.bodyTemplate as NSString).length, length: 0))
        _promptSelection = State(initialValue: NSRange(location: (prompt as NSString).length, length: 0))
    }

    private var prepared: SearchTarget {
        var value = draft
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.template = value.template.trimmingCharacters(in: .whitespacesAndNewlines)
        value.fallbackTemplate = value.fallbackTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        value.aliases = aliasText
            .split { $0.isWhitespace || $0 == "," || $0 == "，" || $0 == "、" }
            .map(String.init)

        if value.kind == .translator {
            var translation = translatorDraft
            translation.credentialID = translation.credentialID?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if translation.credentialID?.isEmpty == true { translation.credentialID = nil }

            if translation.engine == .openAIChat {
                var config = translation.openAI ?? OpenAIChatConfiguration()
                config.baseURL = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                config.model = config.model.trimmingCharacters(in: .whitespacesAndNewlines)
                translation.openAI = config
            } else {
                var config = translation.http ?? HTTPTranslationConfiguration()
                config.method = config.method.uppercased()
                config.url = config.url.trimmingCharacters(in: .whitespacesAndNewlines)
                config.responseJSONPath = config.responseJSONPath.trimmingCharacters(in: .whitespacesAndNewlines)
                if let headers = Self.decodeHeaders(httpHeadersText) { config.headers = headers }
                translation.http = config
            }
            value.translator = translation
            value.openInAppSafari = false
        } else {
            value.translator = nil
        }
        return value
    }

    private var validation: String? {
        if draft.kind == .translator,
           translatorDraft.engine == .http,
           Self.decodeHeaders(httpHeadersText) == nil {
            return "Headers 必须是 JSON object，且所有值都必须是字符串。"
        }
        if draft.kind == .translator,
           !apiKey.isEmpty,
           (translatorDraft.credentialID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            return "保存 API Key 前请先填写 Credential ID。"
        }

        var config = store.configuration
        if let index = config.targets.firstIndex(where: { $0.id == draft.id }) {
            config.targets[index] = prepared
        } else {
            config.targets.append(prepared)
        }
        do {
            try ConfigurationCodec.validate(config)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private var preview: Result<URL, Error> {
        Result { try TemplateEngine.url(template: prepared.template, query: testQuery) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("显示") {
                    HStack {
                        TargetIcon(target: draft, size: 40)
                        TextField("来源名称", text: $draft.name)
                            .accessibilityIdentifier("target-name")
                    }
                    Picker("类型", selection: $draft.kind) {
                        ForEach(SourceKind.allCases) { kind in Text(kind.title).tag(kind) }
                    }
                    .onChange(of: draft.kind) { _, kind in
                        if kind == .translator, draft.translator == nil {
                            translatorDraft = .openAIDefault
                            if translatorDraft.credentialID == nil {
                                translatorDraft.credentialID = "translator.\(draft.id)"
                            }
                            draft.symbol = "character.book.closed.fill"
                        }
                    }

                    Picker("图标", selection: $draft.symbol) {
                        ForEach(Array(Set(symbols + [draft.symbol])).sorted(), id: \.self) { symbol in
                            Label(symbol, systemImage: symbol).tag(symbol)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(colors, id: \.self) { color in
                                Button { draft.tintHex = color } label: {
                                    Circle().fill(Color(hex: color)).frame(width: 25, height: 25)
                                        .overlay {
                                            if draft.tintHex == color {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.bold()).foregroundStyle(.white)
                                            }
                                        }
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("颜色 \(color)")
                            }
                        }
                    }
                }

                if draft.kind == .link {
                    linkSections
                } else {
                    translatorSections
                }

                Section {
                    TextField("例如：b, bili", text: $aliasText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("target-aliases")
                } header: {
                    Text("Trigger Word")
                } footer: {
                    Text("用逗号分隔。搜索链接支持「b 关键词」；翻译来源也可以用 Trigger 直接把当前输入分发到翻译结果页。")
                }

                if let message = validation ?? saveError {
                    Section { Text(message).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle(draft.kind == .translator ? "编辑翻译引擎" : "编辑链接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(validation != nil)
                        .accessibilityIdentifier("save-target")
                }
            }
            .onChange(of: translatorDraft.credentialID) { _, id in
                credentialPresent = id.map(SharedCredentialStore.contains) ?? false
            }
        }
    }

    @ViewBuilder
    private var linkSections: some View {
        Section {
            CursorTemplateEditor(
                text: $draft.template,
                selection: $templateSelection,
                placeholder: "https://example.com/search?q={query}",
                identifier: "target-template"
            )
            Button("插入 {query}") { insert("{query}", into: $draft.template, selection: $templateSelection) }
            if prepared.isAction {
                Label("固定动作：此链接不携带搜索词", systemImage: "bolt")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("搜索链接")
        } footer: {
            Text("把 {query} 放在搜索词的位置；按钮会插入到当前光标或替换当前选区，不再强制追加到末尾。")
        }

        Section {
            TextField("可选：https://example.com/?q={query}", text: $draft.fallbackTemplate, axis: .vertical)
                .font(.system(.subheadline, design: .monospaced))
                .lineLimit(1...4)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("打开失败时的网页兜底")
        } footer: {
            Text("仅在系统无法打开主链接时尝试一次。")
        }

        Section("使用方式") {
            Toggle("启用来源", isOn: $draft.enabled)
            Toggle("App 内 Safari 打开", isOn: Binding(
                get: { draft.usesInAppSafari },
                set: { draft.openInAppSafari = $0 }
            ))
        }

        Section("实时测试") {
            TextField("测试关键词", text: $testQuery)
            switch preview {
            case .success(let url):
                Text(url.absoluteString)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Button("测试打开", systemImage: "arrow.up.right.square") {
                    store.search(testQuery, target: prepared, recordHistory: false)
                }
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var translatorSections: some View {
        Section {
            Picker("引擎", selection: translationBinding(\.engine)) {
                ForEach(TranslationEngineKind.allCases) { engine in Text(engine.title).tag(engine) }
            }

            if translatorDraft.engine == .openAIChat {
                TextField("Base URL，例如 https://api.openai.com", text: openAIBinding(\.baseURL))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Model", text: openAIBinding(\.model))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("System Prompt").font(.caption).foregroundStyle(.secondary)
                CursorTemplateEditor(
                    text: openAIBinding(\.systemPrompt),
                    selection: $promptSelection,
                    placeholder: "Translate from {from} to {to}…",
                    identifier: "translator-system-prompt"
                )
                HStack {
                    Button("{from}") { insert("{from}", into: openAIBinding(\.systemPrompt), selection: $promptSelection) }
                    Button("{to}") { insert("{to}", into: openAIBinding(\.systemPrompt), selection: $promptSelection) }
                    Button("{text}") { insert("{text}", into: openAIBinding(\.systemPrompt), selection: $promptSelection) }
                }
                HStack {
                    Text("Temperature")
                    Slider(value: openAITemperature, in: 0...2, step: 0.1)
                    Text(openAITemperature.wrappedValue.formatted(.number.precision(.fractionLength(1))))
                        .font(.caption.monospacedDigit()).frame(width: 30)
                }
            } else {
                Picker("Method", selection: httpBinding(\.method)) {
                    ForEach(["GET", "POST", "PUT", "PATCH", "DELETE"], id: \.self) { Text($0).tag($0) }
                }

                Text("URL 模板").font(.caption).foregroundStyle(.secondary)
                CursorTemplateEditor(
                    text: httpBinding(\.url),
                    selection: $httpURLSelection,
                    placeholder: "https://example.com/translate?text={text}&from={from}&to={to}",
                    identifier: "translator-http-url"
                )
                tokenButtons(text: httpBinding(\.url), selection: $httpURLSelection, includeCredential: true)

                Text("Headers JSON").font(.caption).foregroundStyle(.secondary)
                CursorTemplateEditor(
                    text: $httpHeadersText,
                    selection: $httpHeadersSelection,
                    placeholder: #"{"Authorization":"Bearer {credential}"}"#,
                    identifier: "translator-http-headers"
                )
                tokenButtons(text: $httpHeadersText, selection: $httpHeadersSelection, includeCredential: true)

                Picker("Body", selection: httpBinding(\.bodyEncoding)) {
                    ForEach(HTTPBodyEncoding.allCases) { encoding in Text(encoding.rawValue.uppercased()).tag(encoding) }
                }

                if (translatorDraft.http ?? HTTPTranslationConfiguration()).bodyEncoding != .none {
                    Text("Body 模板").font(.caption).foregroundStyle(.secondary)
                    CursorTemplateEditor(
                        text: httpBinding(\.bodyTemplate),
                        selection: $bodySelection,
                        placeholder: #"{"text":"{text}","source":"{from}","target":"{to}"}"#,
                        identifier: "translator-http-body"
                    )
                    tokenButtons(text: httpBinding(\.bodyTemplate), selection: $bodySelection, includeCredential: true)
                }

                TextField("JSON Path；留空使用整个响应正文", text: httpBinding(\.responseJSONPath))
                    .font(.system(.subheadline, design: .monospaced))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
        } header: {
            Text("翻译引擎")
        } footer: {
            Text("OpenAI 模式使用 /v1/chat/completions 与 SSE；通用 HTTP 支持 {text}、{from}、{to}、{credential}，JSON Body 会先解析模板再安全替换字符串值。")
        }

        Section {
            TextField("Credential ID", text: Binding(
                get: { translatorDraft.credentialID ?? "" },
                set: { translatorDraft.credentialID = $0.isEmpty ? nil : $0 }
            ))
            .textInputAutocapitalization(.never).autocorrectionDisabled()

            SecureField(credentialPresent ? "API Key（留空保持已保存值）" : "API Key", text: $apiKey)
                .textInputAutocapitalization(.never).autocorrectionDisabled()

            if credentialPresent {
                Label("钥匙串中已有 Key；配置导出不会包含密钥", systemImage: "key.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Button("删除已保存 Key", role: .destructive) {
                    guard let id = translatorDraft.credentialID else { return }
                    do {
                        try SharedCredentialStore.delete(id)
                        credentialPresent = false
                        apiKey = ""
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
            } else {
                Text("Key 单独保存在共享钥匙串中；主 App 和分享扩展都可读取，导出 JSON 只保留 Credential ID。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("API Key")
        }

        Section("使用方式") {
            Toggle("启用来源", isOn: $draft.enabled)
            Toggle("自动运行", isOn: translationBinding(\.autoRun))
            Text("进入翻译结果页时，会自动运行你点中的引擎和所有开启「自动运行」的引擎；其他卡片可手动运行或点「全部翻译」。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var openAITemperature: Binding<Double> {
        Binding(
            get: { translatorDraft.openAI?.temperature ?? 0.2 },
            set: { value in
                var config = translatorDraft.openAI ?? OpenAIChatConfiguration()
                config.temperature = value
                translatorDraft.openAI = config
            }
        )
    }

    private func translationBinding<Value>(_ keyPath: WritableKeyPath<TranslationConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { translatorDraft[keyPath: keyPath] },
            set: { translatorDraft[keyPath: keyPath] = $0 }
        )
    }

    private func openAIBinding<Value>(_ keyPath: WritableKeyPath<OpenAIChatConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { (translatorDraft.openAI ?? OpenAIChatConfiguration())[keyPath: keyPath] },
            set: { value in
                var config = translatorDraft.openAI ?? OpenAIChatConfiguration()
                config[keyPath: keyPath] = value
                translatorDraft.openAI = config
            }
        )
    }

    private func httpBinding<Value>(_ keyPath: WritableKeyPath<HTTPTranslationConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { (translatorDraft.http ?? HTTPTranslationConfiguration())[keyPath: keyPath] },
            set: { value in
                var config = translatorDraft.http ?? HTTPTranslationConfiguration()
                config[keyPath: keyPath] = value
                translatorDraft.http = config
            }
        )
    }

    private func tokenButtons(text: Binding<String>, selection: Binding<NSRange>, includeCredential: Bool) -> some View {
        HStack {
            Button("{text}") { insert("{text}", into: text, selection: selection) }
            Button("{from}") { insert("{from}", into: text, selection: selection) }
            Button("{to}") { insert("{to}", into: text, selection: selection) }
            if includeCredential {
                Button("{credential}") { insert("{credential}", into: text, selection: selection) }
            }
        }
        .font(.caption)
    }

    private func save() {
        let value = prepared
        do {
            if value.kind == .translator,
               !apiKey.isEmpty,
               let id = value.translator?.credentialID {
                try SharedCredentialStore.set(apiKey, for: id)
            }
            try store.upsert(value)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func insert(_ token: String, into text: inout String, selection: inout NSRange) {
        let result = Self.inserting(token, into: text, selection: selection)
        text = result.text
        selection = result.selection
    }

    private func insert(_ token: String, into text: Binding<String>, selection: Binding<NSRange>) {
        let result = Self.inserting(token, into: text.wrappedValue, selection: selection.wrappedValue)
        text.wrappedValue = result.text
        selection.wrappedValue = result.selection
    }

    private static func inserting(_ token: String, into text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        TextInsertion.inserting(token, into: text, selection: selection)
    }

    private static func encodeHeaders(_ headers: [String: String]) -> String {
        guard !headers.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: headers, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    private static func decodeHeaders(_ text: String) -> [String: String]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [:] }
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else { return nil }
        var result: [String: String] = [:]
        for (key, value) in dictionary {
            guard let string = value as? String else { return nil }
            result[key] = string
        }
        return result
    }
}
