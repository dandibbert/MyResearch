import Foundation
#if SWIFT_PACKAGE
import TranslationCore
#endif

enum SourceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case link, translator
    var id: String { rawValue }
    var title: String {
        switch self {
        case .link: return "链接"
        case .translator: return "翻译"
        }
    }
}

struct SearchTarget: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var name: String
    var symbol: String
    var tintHex: String
    var template: String
    var fallbackTemplate: String
    var aliases: [String]
    var enabled: Bool
    var quickAccess: Bool
    var openInAppSafari: Bool?
    var kind: SourceKind
    var translator: TranslationConfiguration?

    init(
        id: String = UUID().uuidString,
        name: String = "",
        symbol: String = "magnifyingglass",
        tintHex: String = "5265DE",
        template: String = "https://www.google.com/search?q={query}",
        fallbackTemplate: String = "",
        aliases: [String] = [],
        enabled: Bool = true,
        quickAccess: Bool = false,
        openInAppSafari: Bool? = nil,
        kind: SourceKind = .link,
        translator: TranslationConfiguration? = nil
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.tintHex = tintHex
        self.template = template
        self.fallbackTemplate = fallbackTemplate
        self.aliases = aliases
        self.enabled = enabled
        self.quickAccess = quickAccess
        self.openInAppSafari = openInAppSafari
        self.kind = kind
        self.translator = translator
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, symbol, tintHex, template, fallbackTemplate, aliases, enabled
        case quickAccess, openInAppSafari, kind, translator
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        symbol = try values.decodeIfPresent(String.self, forKey: .symbol) ?? "magnifyingglass"
        tintHex = try values.decodeIfPresent(String.self, forKey: .tintHex) ?? "5265DE"
        template = try values.decodeIfPresent(String.self, forKey: .template) ?? ""
        fallbackTemplate = try values.decodeIfPresent(String.self, forKey: .fallbackTemplate) ?? ""
        aliases = try values.decodeIfPresent([String].self, forKey: .aliases) ?? []
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        quickAccess = try values.decodeIfPresent(Bool.self, forKey: .quickAccess) ?? false
        openInAppSafari = try values.decodeIfPresent(Bool.self, forKey: .openInAppSafari)
        kind = try values.decodeIfPresent(SourceKind.self, forKey: .kind) ?? .link
        translator = try values.decodeIfPresent(TranslationConfiguration.self, forKey: .translator)
    }

    var usesInAppSafari: Bool { openInAppSafari ?? false }
    var isAction: Bool { kind == .link && !template.contains("{query}") }
    var translatorDetail: String? {
        guard kind == .translator else { return nil }
        return translator?.engine.title ?? "翻译引擎"
    }
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
    var inAppSafariEnabled: Bool? = true

    // Optional for backward-compatible decoding of existing schema v2 files.
    var translationPairPromptEnabled: Bool?
    var translationPreferredTargetLanguage: String?
    var lastTranslationSourceLanguage: String?
    var lastTranslationTargetLanguage: String?

    var usesInAppSafari: Bool { inAppSafariEnabled ?? true }
    var usesTranslationPairPrompt: Bool { translationPairPromptEnabled ?? true }
}

struct HistoryItem: Identifiable, Codable, Equatable, Sendable {
    var id = UUID().uuidString
    var query: String
    var targetID: String
    var date = Date()
}

struct Configuration: Codable, Equatable, Sendable {
    var schemaVersion = 2
    var targets: [SearchTarget]
    var settings: AppSettings

    static var initial: Configuration {
        Configuration(targets: Presets.initial, settings: AppSettings())
    }
    var enabledTargets: [SearchTarget] { targets.filter(\.enabled) }
    var enabledLinks: [SearchTarget] { enabledTargets.filter { $0.kind == .link } }
    var enabledTranslators: [SearchTarget] { enabledTargets.filter { $0.kind == .translator && $0.translator != nil } }
    var quickTargets: [SearchTarget] { enabledTargets }
    var defaultTarget: SearchTarget? {
        enabledLinks.first { $0.id == settings.defaultTargetID } ?? enabledLinks.first
    }
}

struct ResearchError: LocalizedError, Equatable {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum ConfigurationCodec {
    static func encode(_ configuration: Configuration) throws -> Data {
        let normalized = try normalize(configuration)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(normalized)
    }

    static func decode(_ data: Data) throws -> Configuration {
        guard data.count <= 2_000_000 else { throw ResearchError("配置文件不能超过 2 MB。") }
        let decoded: Configuration
        do { decoded = try JSONDecoder().decode(Configuration.self, from: data) }
        catch { throw ResearchError("这不是有效的 MyResearch 配置文件，或存在缺失/错误的字段。") }
        return try normalize(decoded)
    }

    static func normalize(_ configuration: Configuration) throws -> Configuration {
        var result = configuration
        switch result.schemaVersion {
        case 1:
            result.schemaVersion = 2
            for index in result.targets.indices where result.targets[index].kind == .link {
                result.targets[index].translator = nil
            }
        case 2:
            break
        default:
            throw ResearchError("不支持此配置版本，请先升级 App。")
        }
        try validate(result)
        return result
    }

    static func validate(_ configuration: Configuration) throws {
        guard configuration.schemaVersion == 2 else { throw ResearchError("不支持此配置版本，请先升级 App。") }
        guard configuration.targets.count <= 200 else { throw ResearchError("最多保存 200 个来源。") }
        guard (1...12).contains(configuration.settings.maxSuggestions) else { throw ResearchError("候选数量须为 1–12。") }
        var ids = Set<String>()
        var aliases = Set<String>()

        for target in configuration.targets {
            guard !target.id.isEmpty, ids.insert(target.id).inserted else { throw ResearchError("来源 ID 重复或为空。") }
            guard !target.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, target.name.count <= 80 else {
                throw ResearchError("来源名称不能为空或超过 80 字。")
            }
            guard target.symbol.count <= 100,
                  target.tintHex.range(of: "^[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else {
                throw ResearchError("图标或颜色格式无效。")
            }

            switch target.kind {
            case .link:
                _ = try TemplateEngine.url(template: target.template, query: "测试 & + # / 🐈")
                if !target.fallbackTemplate.isEmpty {
                    let fallback = try TemplateEngine.url(template: target.fallbackTemplate, query: "测试")
                    guard fallback.scheme?.lowercased() == "https" else { throw ResearchError("网页兜底必须使用 HTTPS。") }
                }
            case .translator:
                guard let translator = target.translator else {
                    throw ResearchError("翻译来源「\(target.name)」缺少引擎配置。")
                }
                do { try TranslationConfigurationValidator.validate(translator) }
                catch { throw ResearchError(error.localizedDescription) }
            }

            guard target.aliases.count <= 12 else { throw ResearchError("每个来源最多 12 个触发词。") }
            for alias in target.aliases {
                guard !alias.isEmpty, alias.count <= 40, !alias.contains(where: \.isWhitespace) else {
                    throw ResearchError("触发词不能为空、包含空格或超过 40 字。")
                }
                guard aliases.insert(alias.lowercased()).inserted else {
                    throw ResearchError("触发词「\(alias)」重复。每个触发词只能分配给一个来源。")
                }
            }
        }
    }
}
