import Foundation

struct SharedSearchInput: Equatable {
    var text: String
    var wasTruncated: Bool
}

enum SharedInputResolver {
    static func resolve(selection: [String] = [], texts: [String] = [], urls: [String] = []) -> SharedSearchInput {
        for values in [selection, texts, urls] {
            let cleaned = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if let first = cleaned.first {
                return SharedSearchInput(text: String(first.prefix(4096)), wasTruncated: first.count > 4096)
            }
        }
        return SharedSearchInput(text: "", wasTruncated: false)
    }
}

struct ShareHandoff: Equatable {
    var query: String
    var targetID: String?
    var run: Bool
    func url() throws -> URL {
        guard query.count <= 4096 else { throw ResearchError("分享文字最多 4096 字。") }
        var parts = URLComponents()
        parts.scheme = "myresearch"
        parts.host = "share"
        parts.queryItems = [URLQueryItem(name: "q", value: query)]
        if let targetID { parts.queryItems?.append(URLQueryItem(name: "target", value: targetID)) }
        if run { parts.queryItems?.append(URLQueryItem(name: "run", value: "1")) }
        guard let url = parts.url else { throw ResearchError("无法生成接力链接。") }
        return url
    }
    static func parse(_ url: URL) -> ShareHandoff? {
        guard url.scheme?.lowercased() == "myresearch", ["share", "search"].contains(url.host ?? ""),
              url.user == nil, url.password == nil, url.port == nil,
              url.path.isEmpty || url.path == "/",
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = parts.queryItems ?? []
        guard items.filter({ $0.name == "q" }).count == 1,
              items.filter({ $0.name == "target" }).count <= 1,
              items.filter({ $0.name == "run" }).count <= 1,
              let query = items.first(where: { $0.name == "q" })?.value, query.count <= 4096 else { return nil }
        let id = items.first(where: { $0.name == "target" })?.value
        guard id == nil || (id!.count <= 200 && !id!.isEmpty) else { return nil }
        return ShareHandoff(query: query, targetID: id, run: items.first(where: { $0.name == "run" })?.value == "1")
    }
}

struct ConfigurationSnapshot: Codable {
    var configuration: Configuration
    var updatedAt = Date()
    static func decode(_ data: Data) throws -> ConfigurationSnapshot {
        guard data.count <= 2_100_000 else { throw ResearchError("共享配置过大。") }
        let value = try JSONDecoder().decode(Self.self, from: data)
        try ConfigurationCodec.validate(value.configuration)
        return value
    }
}
