import Foundation

struct OpenAIModelCatalog {
    static func fetch(
        baseURL: String,
        credential: String,
        extraHeaders: [String: String] = [:],
        session: URLSession = .shared
    ) async throws -> [String] {
        let url = try modelsURL(baseURL: baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !credential.isEmpty {
            request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        }

        let values = TranslationTemplateValues(
            text: "",
            from: "auto",
            to: "zh",
            credential: credential
        )
        let headers = try TranslationTemplateRenderer.renderHeaders(extraHeaders, values: values)
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ModelCatalogError.invalidResponse("模型接口没有返回 HTTP 响应。")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data.prefix(8_192), encoding: .utf8) ?? "无响应正文"
            throw ModelCatalogError.httpStatus(http.statusCode, body)
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw ModelCatalogError.invalidResponse("模型接口返回的不是有效 JSON。")
        }

        var valuesList: [String] = []
        if let root = object as? [String: Any] {
            if let data = root["data"] as? [[String: Any]] {
                valuesList.append(contentsOf: data.compactMap { $0["id"] as? String })
            }
            if let models = root["models"] as? [[String: Any]] {
                valuesList.append(contentsOf: models.compactMap {
                    ($0["id"] as? String) ?? ($0["name"] as? String)
                })
            }
        } else if let rows = object as? [[String: Any]] {
            valuesList.append(contentsOf: rows.compactMap {
                ($0["id"] as? String) ?? ($0["name"] as? String)
            })
        }

        let cleaned = Array(Set(valuesList.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        guard !cleaned.isEmpty else {
            throw ModelCatalogError.invalidResponse("模型接口没有返回可选择的模型。仍可在高级设置中手动填写模型名。")
        }
        return cleaned
    }

    static func modelsURL(baseURL: String) throws -> URL {
        let raw = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.user == nil,
              url.password == nil else {
            throw ModelCatalogError.invalidBaseURL
        }

        let lower = url.path.lowercased()
        if lower.hasSuffix("/models") {
            return url
        }
        if lower.hasSuffix("/chat/completions") {
            url.deleteLastPathComponent()
            url.deleteLastPathComponent()
            url.appendPathComponent("models")
            return url
        }
        if lower.hasSuffix("/v1") {
            url.appendPathComponent("models")
            return url
        }

        url.appendPathComponent("v1")
        url.appendPathComponent("models")
        return url
    }
}

private enum ModelCatalogError: LocalizedError {
    case invalidBaseURL
    case httpStatus(Int, String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Base URL 无效，无法获取模型。"
        case .httpStatus(let code, let message):
            return "获取模型失败（HTTP \(code)）：\(message)"
        case .invalidResponse(let message):
            return message
        }
    }
}

struct ModelPickerSheet: View {
    let models: [String]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [String] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return models }
        return models.filter { $0.localizedCaseInsensitiveContains(term) }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "没有匹配模型",
                        systemImage: "magnifyingglass",
                        description: Text("换一个关键词，或者在高级设置中手动输入模型名。")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filtered, id: \.self) { model in
                        Button {
                            selection = model
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selection == model ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection == model ? ResearchStyle.accent : Color.secondary)
                                Text(model)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("选择模型")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "搜索模型")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
