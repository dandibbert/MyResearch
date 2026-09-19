import Foundation

struct SearchTarget: Identifiable, Codable, Equatable, Sendable {
    var id = UUID().uuidString
    var name = ""
    var symbol = "magnifyingglass"
    var tintHex = "5265DE"
    var template = "https://www.google.com/search?q={query}"
    var fallbackTemplate = ""
    var aliases: [String] = []
    var enabled = true
    var quickAccess = false
    var isAction: Bool { !template.contains("{query}") }
}

enum SuggestionProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case bing, google, local, off
    var id: String { rawValue }
    var title: String {
        switch self { case .bing: return "Bing"; case .google: return "Google"
        case .local: return "仅本地历史"; case .off: return "关闭" }
    }
    var isRemote: Bool { self == .bing || self == .google }
}

struct AppSettings: Codable, Equatable, Sendable {
    var autoFocus = true
    var thumbLayout = true
    var lightning = true
    var provider = SuggestionProvider.bing
    var historyEnabled = true
    var maxSuggestions = 6
    var defaultTargetID = "google"
}

struct HistoryItem: Identifiable, Codable, Equatable, Sendable {
    var id = UUID().uuidString
    var query: String
    var targetID: String
    var date = Date()
}

struct Configuration: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var targets: [SearchTarget]
    var settings: AppSettings

    static var initial: Configuration {
        Configuration(targets: Presets.initial, settings: AppSettings())
    }
    var enabledTargets: [SearchTarget] { targets.filter(\.enabled) }
    var quickTargets: [SearchTarget] { Array(enabledTargets.filter(\.quickAccess).prefix(3)) }
    var defaultTarget: SearchTarget? {
        enabledTargets.first { $0.id == settings.defaultTargetID } ?? enabledTargets.first
    }
}

struct ResearchError: LocalizedError, Equatable {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum ConfigurationCodec {
    static func encode(_ configuration: Configuration) throws -> Data {
        try validate(configuration)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(configuration)
    }
    static func decode(_ data: Data) throws -> Configuration {
        guard data.count <= 2_000_000 else { throw ResearchError("配置文件不能超过 2 MB。") }
        let result: Configuration
        do { result = try JSONDecoder().decode(Configuration.self, from: data) }
        catch { throw ResearchError("这不是有效的 MyResearch 配置文件，或存在缺失/错误的字段。") }
        try validate(result)
        return result
    }
    static func validate(_ configuration: Configuration) throws {
        guard configuration.schemaVersion == 1 else { throw ResearchError("不支持此配置版本，请先升级 App。") }
        guard configuration.targets.count <= 200 else { throw ResearchError("最多保存 200 个链接。") }
        guard (1...12).contains(configuration.settings.maxSuggestions) else { throw ResearchError("候选数量须为 1–12。") }
        var ids = Set<String>()
        var aliases = Set<String>()
        for target in configuration.targets {
            guard !target.id.isEmpty, ids.insert(target.id).inserted else { throw ResearchError("链接 ID 重复或为空。") }
            guard !target.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, target.name.count <= 80 else {
                throw ResearchError("链接名称不能为空或超过 80 字。")
            }
            guard target.symbol.count <= 100,
                  target.tintHex.range(of: "^[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else {
                throw ResearchError("图标或颜色格式无效。")
            }
            _ = try TemplateEngine.url(template: target.template, query: "测试 & + # / 🐈")
            if !target.fallbackTemplate.isEmpty {
                let fallback = try TemplateEngine.url(template: target.fallbackTemplate, query: "测试")
                guard fallback.scheme?.lowercased() == "https" else { throw ResearchError("网页兜底必须使用 HTTPS。") }
            }
            guard target.aliases.count <= 12 else { throw ResearchError("每个链接最多 12 个触发词。") }
            for alias in target.aliases {
                guard !alias.isEmpty, alias.count <= 40, !alias.contains(where: \.isWhitespace) else {
                    throw ResearchError("触发词不能为空、包含空格或超过 40 字。")
                }
                guard aliases.insert(alias.lowercased()).inserted else {
                    throw ResearchError("触发词「\(alias)」重复。每个触发词只能分配给一个链接。")
                }
            }
        }
    }
}
