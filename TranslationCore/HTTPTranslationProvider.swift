import Foundation

public struct HTTPTranslationProvider: TranslationProvider, @unchecked Sendable {
    public let configuration: HTTPTranslationConfiguration
    public let credential: String
    public let session: URLSession

    public init(
        configuration: HTTPTranslationConfiguration,
        credential: String = "",
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.credential = credential
        self.session = session
    }

    public func translate(_ request: TranslationRequest) -> AsyncThrowingStream<TranslationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let values = TranslationTemplateValues(
                        text: request.text,
                        from: request.sourceLanguage ?? "auto",
                        to: request.targetLanguage,
                        credential: credential
                    )
                    let urlString = try TranslationTemplateRenderer.renderURL(configuration.url, values: values)
                    guard let url = URL(string: urlString),
                          let scheme = url.scheme?.lowercased(),
                          ["http", "https"].contains(scheme),
                          url.user == nil, url.password == nil else {
                        throw TranslationCoreError.invalidConfiguration("通用 HTTP 翻译 URL 无效。")
                    }

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = configuration.method.uppercased()
                    let headers = try TranslationTemplateRenderer.renderHeaders(configuration.headers, values: values)
                    headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
                    urlRequest.httpBody = try TranslationTemplateRenderer.renderBody(
                        encoding: configuration.bodyEncoding,
                        template: configuration.bodyTemplate,
                        values: values
                    )
                    if configuration.bodyEncoding == .json, urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    } else if configuration.bodyEncoding == .form, urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                        urlRequest.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
                    }

                    let (data, response) = try await session.data(for: urlRequest)
                    guard data.count <= 4_000_000 else {
                        throw TranslationCoreError.invalidResponse("翻译接口响应超过 4 MB。")
                    }
                    guard let http = response as? HTTPURLResponse else {
                        throw TranslationCoreError.invalidResponse("翻译接口没有返回 HTTP 响应。")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        let message = String(data: data.prefix(8_192), encoding: .utf8) ?? "无响应正文"
                        throw TranslationCoreError.httpStatus(http.statusCode, message)
                    }

                    let path = configuration.responseJSONPath.trimmingCharacters(in: .whitespacesAndNewlines)
                    let translated: String
                    if path.isEmpty {
                        guard let value = String(data: data, encoding: .utf8), !value.isEmpty else {
                            throw TranslationCoreError.invalidResponse("翻译接口返回了空响应。")
                        }
                        translated = value
                    } else {
                        let object: Any
                        do {
                            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                        } catch {
                            throw TranslationCoreError.invalidResponse("翻译接口返回的不是有效 JSON。")
                        }
                        translated = try TranslationJSONPath.string(at: path, in: object)
                    }

                    try Task.checkCancellation()
                    continuation.yield(.replacement(translated))
                    continuation.yield(.completed(TranslationResult(
                        text: translated,
                        detectedLanguage: request.sourceLanguage,
                        targetLanguage: request.targetLanguage
                    )))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
