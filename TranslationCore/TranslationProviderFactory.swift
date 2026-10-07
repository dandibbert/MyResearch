import Foundation

public enum TranslationConfigurationValidator {
    public static func validate(_ configuration: TranslationConfiguration) throws {
        if let credentialID = configuration.credentialID {
            let value = credentialID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value.count <= 200, !value.contains("\n"), !value.contains("\r") else {
                throw TranslationCoreError.invalidConfiguration("Credential ID 无效。")
            }
        }

        switch configuration.engine {
        case .openAIChat:
            guard let config = configuration.openAI else {
                throw TranslationCoreError.invalidConfiguration("缺少 OpenAI Chat Completions 配置。")
            }
            guard let url = URL(string: config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
                  url.user == nil, url.password == nil else {
                throw TranslationCoreError.invalidConfiguration("OpenAI-compatible Base URL 无效。")
            }
            guard !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, config.model.count <= 200 else {
                throw TranslationCoreError.invalidConfiguration("模型名称不能为空或超过 200 字。")
            }
            guard !config.systemPrompt.isEmpty, config.systemPrompt.count <= 16_000 else {
                throw TranslationCoreError.invalidConfiguration("System Prompt 不能为空或超过 16000 字。")
            }
            if let temperature = config.temperature {
                guard (0...2).contains(temperature) else {
                    throw TranslationCoreError.invalidConfiguration("Temperature 须在 0–2 之间。")
                }
            }
            guard config.extraHeaders.count <= 32 else {
                throw TranslationCoreError.invalidConfiguration("最多配置 32 个额外 Header。")
            }
            _ = try TranslationTemplateRenderer.renderText(
                config.systemPrompt,
                values: TranslationTemplateValues(text: "hello", from: "en", to: "zh", credential: "secret")
            )
            _ = try TranslationTemplateRenderer.renderHeaders(
                config.extraHeaders,
                values: TranslationTemplateValues(text: "hello", from: "en", to: "zh", credential: "secret")
            )

        case .http:
            guard let config = configuration.http else {
                throw TranslationCoreError.invalidConfiguration("缺少通用 HTTP 翻译配置。")
            }
            let method = config.method.uppercased()
            guard ["GET", "POST", "PUT", "PATCH", "DELETE"].contains(method) else {
                throw TranslationCoreError.invalidConfiguration("HTTP Method 仅支持 GET/POST/PUT/PATCH/DELETE。")
            }
            guard config.url.count <= 8_192, config.bodyTemplate.count <= 65_536,
                  config.responseJSONPath.count <= 512, config.headers.count <= 32 else {
                throw TranslationCoreError.invalidConfiguration("HTTP 翻译配置过长。")
            }
            let values = TranslationTemplateValues(text: "测试 & + # / 🐈", from: "zh", to: "en", credential: "secret")
            let renderedURL = try TranslationTemplateRenderer.renderURL(config.url, values: values)
            guard let url = URL(string: renderedURL),
                  let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
                  url.user == nil, url.password == nil else {
                throw TranslationCoreError.invalidConfiguration("通用 HTTP 翻译 URL 无效。")
            }
            _ = try TranslationTemplateRenderer.renderHeaders(config.headers, values: values)
            _ = try TranslationTemplateRenderer.renderBody(encoding: config.bodyEncoding, template: config.bodyTemplate, values: values)
            let path = config.responseJSONPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard path.isEmpty || path.first == "$" else {
                throw TranslationCoreError.invalidConfiguration("JSON Path 必须以 $ 开头；留空则使用整个响应正文。")
            }
        }
    }
}

public enum TranslationProviderFactory {
    public static func make(
        configuration: TranslationConfiguration,
        credential: String?,
        session: URLSession = .shared
    ) throws -> any TranslationProvider {
        try TranslationConfigurationValidator.validate(configuration)
        switch configuration.engine {
        case .openAIChat:
            guard let config = configuration.openAI else {
                throw TranslationCoreError.invalidConfiguration("缺少 OpenAI Chat Completions 配置。")
            }
            return OpenAIChatProvider(configuration: config, credential: credential ?? "", session: session)
        case .http:
            guard let config = configuration.http else {
                throw TranslationCoreError.invalidConfiguration("缺少通用 HTTP 翻译配置。")
            }
            return HTTPTranslationProvider(configuration: config, credential: credential ?? "", session: session)
        }
    }
}
