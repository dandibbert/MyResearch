import Foundation

enum TemplateEngine {
    // Encoding an individual value with urlQueryAllowed would leak &, +, # and /.
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    static func url(template: String, query: String) throws -> URL {
        guard !template.isEmpty, template.count <= 8192, !template.contains(where: \.isWhitespace) else {
            throw ResearchError("链接模板不能为空、含空白或超过 8192 字；空格请使用 %20。")
        }
        guard query.count <= 4096 else { throw ResearchError("搜索词过长，最多 4096 字。") }
        let skeleton = template.replacingOccurrences(of: "{query}", with: "")
        guard !skeleton.contains("{"), !skeleton.contains("}"),
              skeleton.range(of: "%(?![0-9A-Fa-f]{2})", options: .regularExpression) == nil else {
            throw ResearchError("只支持 {query} 占位符；百分号需使用有效编码，如 %20。")
        }
        if template.contains("{query}") && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ResearchError("先输入要搜索的内容。")
        }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: unreserved),
              let result = URL(string: template.replacingOccurrences(of: "{query}", with: encoded)),
              let scheme = result.scheme?.lowercased(),
              scheme.range(of: "^[a-z][a-z0-9+.-]*$", options: .regularExpression) != nil else {
            throw ResearchError("链接无效。请填写完整 HTTPS 地址或 App URL Scheme。")
        }
        guard !["javascript", "data", "file", "about", "myresearch"].contains(scheme) else {
            throw ResearchError("不允许此链接协议。")
        }
        if scheme == "https" || scheme == "http" {
            guard let host = result.host, !host.isEmpty, result.user == nil, result.password == nil else {
                throw ResearchError("网页链接需要有效域名，且不能包含用户名或密码。")
            }
        }
        return result
    }
}

struct SearchIntent: Equatable, Sendable {
    var query: String
    var targetID: String?
}

enum SearchRouter {
    static func intent(for input: String, configuration: Configuration) -> SearchIntent {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard configuration.settings.lightning else { return SearchIntent(query: text, targetID: nil) }
        let tokens = text.split(whereSeparator: \.isWhitespace)
        guard tokens.count > 1, let first = tokens.first, let last = tokens.last else {
            return SearchIntent(query: text, targetID: nil)
        }
        func match(_ word: Substring) -> SearchTarget? {
            configuration.enabledTargets.first { target in target.aliases.contains { $0.lowercased() == word.lowercased() } }
        }
        if let target = match(first) {
            return SearchIntent(query: String(text.dropFirst(first.count)).trimmingCharacters(in: .whitespacesAndNewlines), targetID: target.id)
        }
        if let target = match(last) {
            return SearchIntent(query: String(text.dropLast(last.count)).trimmingCharacters(in: .whitespacesAndNewlines), targetID: target.id)
        }
        return SearchIntent(query: text, targetID: nil)
    }
}

enum SuggestionLogic {
    static func parse(_ data: Data) throws -> [String] {
        guard data.count <= 128_000,
              let array = try JSONSerialization.jsonObject(with: data) as? [Any],
              array.count > 1, let strings = array[1] as? [String] else {
            throw ResearchError("联想服务返回了无法识别的内容。")
        }
        return strings
    }
    static func clean(_ values: [String], query: String, limit: Int) -> [String] {
        guard !query.isEmpty, limit > 0 else { return [] }
        var seen: Set<String> = [query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
        var result: [String] = []
        for value in values {
            let term = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !term.isEmpty, term.count <= 200, !term.contains("\n"), seen.insert(term.lowercased()).inserted {
                result.append(term)
            }
            if result.count == limit { break }
        }
        return result
    }
    static func local(_ history: [HistoryItem], query: String, limit: Int) -> [String] {
        clean(history.filter { $0.query.localizedCaseInsensitiveContains(query) }.map(\.query), query: query, limit: limit)
    }
    static func recording(_ history: [HistoryItem], query: String, targetID: String) -> [HistoryItem] {
        guard !query.isEmpty else { return history }
        let rest = history.filter { !($0.query == query && $0.targetID == targetID) }
        return [HistoryItem(query: query, targetID: targetID)] + Array(rest.prefix(99))
    }
}
