import Foundation
import SwiftUI

actor SuggestionService {
    private let session: URLSession
    private var cache: [String: (Date, [String])] = [:]
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 5
        config.httpShouldSetCookies = false
        config.urlCache = nil
        session = URLSession(configuration: config)
    }
    func fetch(query: String, provider: SuggestionProvider) async throws -> [String] {
        let key = provider.rawValue + "\n" + query
        if let entry = cache[key], Date().timeIntervalSince(entry.0) < 180 { return entry.1 }
        let template: String
        switch provider {
        case .bing: template = "https://api.bing.com/osjson.aspx?query={query}"
        case .google: template = "https://suggestqueries.google.com/complete/search?client=firefox&hl=zh-CN&q={query}"
        default: return []
        }
        var request = URLRequest(url: try TemplateEngine.url(template: template, query: query))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ResearchError("联想服务暂不可用。")
        }
        let result = try SuggestionLogic.parse(data)
        if cache.count >= 100 { cache.removeAll() }
        cache[key] = (Date(), result)
        return result
    }
}

@MainActor
final class SuggestionsModel: ObservableObject {
    @Published private(set) var values: [String] = []
    @Published private(set) var loading = false
    @Published private(set) var status = ""
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private let service = SuggestionService()

    func cancel() { task?.cancel(); generation = UUID(); loading = false }
    func refresh(query: String, settings: AppSettings, history: [HistoryItem], testMode: Bool) {
        cancel()
        let current = generation
        let records = settings.historyEnabled ? history : []
        values = []
        status = settings.provider.title
        guard !query.isEmpty, settings.provider != .off else { return }
        values = SuggestionLogic.local(records, query: query, limit: settings.maxSuggestions)
        guard settings.provider.isRemote else { return }
        loading = true
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: testMode ? 1_200_000_000 : 250_000_000)
                let fetched: [String]
                if testMode { fetched = [query, query + " 年龄", query + " 资料", query + " 讨论", query + " 资料"] }
                else { fetched = try await service.fetch(query: query, provider: settings.provider) }
                try Task.checkCancellation()
                guard generation == current else { return }
                values = SuggestionLogic.clean(fetched, query: query, limit: settings.maxSuggestions)
                loading = false
                status = testMode ? "测试联想" : settings.provider.title
            } catch {
                guard !Task.isCancelled, generation == current else { return }
                loading = false
                status = "联想暂不可用 · 仍可搜索原词"
            }
        }
    }
}
