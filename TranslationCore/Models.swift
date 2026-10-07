import Foundation

public struct TranslationRequest: Equatable, Sendable {
    public var text: String
    public var sourceLanguage: String?
    public var targetLanguage: String

    public init(text: String, sourceLanguage: String? = nil, targetLanguage: String) {
        self.text = text
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public struct TranslationResult: Equatable, Sendable {
    public var text: String
    public var detectedLanguage: String?
    public var targetLanguage: String

    public init(text: String, detectedLanguage: String? = nil, targetLanguage: String) {
        self.text = text
        self.detectedLanguage = detectedLanguage
        self.targetLanguage = targetLanguage
    }
}

public enum TranslationEvent: Equatable, Sendable {
    case delta(String)
    case replacement(String)
    case completed(TranslationResult)
}

public protocol TranslationProvider: Sendable {
    func translate(_ request: TranslationRequest) -> AsyncThrowingStream<TranslationEvent, Error>
}

public enum TranslationEngineKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAIChat = "openai-chat"
    case http

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .openAIChat: return "OpenAI Chat Completions"
        case .http: return "通用 HTTP"
        }
    }
}

public enum HTTPBodyEncoding: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, json, form, raw
    public var id: String { rawValue }
}

public struct OpenAIChatConfiguration: Codable, Equatable, Sendable {
    public var baseURL: String
    public var model: String
    public var systemPrompt: String
    public var temperature: Double?
    public var extraHeaders: [String: String]

    public init(
        baseURL: String = "https://api.openai.com",
        model: String = "",
        systemPrompt: String = "Translate the following text from {from} to {to}. Return only the translation, without explanations.",
        temperature: Double? = 0.2,
        extraHeaders: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.model = model
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.extraHeaders = extraHeaders
    }
}

public struct HTTPTranslationConfiguration: Codable, Equatable, Sendable {
    public var method: String
    public var url: String
    public var headers: [String: String]
    public var bodyEncoding: HTTPBodyEncoding
    public var bodyTemplate: String
    public var responseJSONPath: String

    public init(
        method: String = "POST",
        url: String = "",
        headers: [String: String] = [:],
        bodyEncoding: HTTPBodyEncoding = .json,
        bodyTemplate: String = #"{"text":"{text}","source":"{from}","target":"{to}"}"#,
        responseJSONPath: String = "$.data.translation"
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.bodyEncoding = bodyEncoding
        self.bodyTemplate = bodyTemplate
        self.responseJSONPath = responseJSONPath
    }
}

public struct TranslationConfiguration: Codable, Equatable, Sendable {
    public var engine: TranslationEngineKind
    public var openAI: OpenAIChatConfiguration?
    public var http: HTTPTranslationConfiguration?
    public var credentialID: String?
    public var autoRun: Bool

    public init(
        engine: TranslationEngineKind = .openAIChat,
        openAI: OpenAIChatConfiguration? = OpenAIChatConfiguration(),
        http: HTTPTranslationConfiguration? = nil,
        credentialID: String? = nil,
        autoRun: Bool = false
    ) {
        self.engine = engine
        self.openAI = openAI
        self.http = http
        self.credentialID = credentialID
        self.autoRun = autoRun
    }

    public static var openAIDefault: TranslationConfiguration {
        TranslationConfiguration()
    }

    public static var httpDefault: TranslationConfiguration {
        TranslationConfiguration(engine: .http, openAI: nil, http: HTTPTranslationConfiguration())
    }
}

public enum TranslationCoreError: LocalizedError, Equatable {
    case invalidConfiguration(String)
    case invalidTemplate(String)
    case invalidResponse(String)
    case httpStatus(Int, String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message), .invalidTemplate(let message), .invalidResponse(let message):
            return message
        case .httpStatus(let status, let message):
            return "翻译接口返回 HTTP \(status)：\(message)"
        }
    }
}
