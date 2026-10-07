import Foundation

public struct OpenAIChatProvider: TranslationProvider, @unchecked Sendable {
    public let configuration: OpenAIChatConfiguration
    public let credential: String
    public let session: URLSession

    public init(
        configuration: OpenAIChatConfiguration,
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
                    let url = try endpointURL()
                    let values = TranslationTemplateValues(
                        text: request.text,
                        from: request.sourceLanguage ?? "auto",
                        to: request.targetLanguage,
                        credential: credential
                    )
                    let prompt = try TranslationTemplateRenderer.renderText(configuration.systemPrompt, values: values)
                    var payload: [String: Any] = [
                        "model": configuration.model,
                        "stream": true,
                        "messages": [
                            ["role": "system", "content": prompt],
                            ["role": "user", "content": request.text],
                        ],
                    ]
                    if let temperature = configuration.temperature { payload["temperature"] = temperature }

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    if !credential.isEmpty { urlRequest.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization") }
                    let extra = try TranslationTemplateRenderer.renderHeaders(configuration.extraHeaders, values: values)
                    extra.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else {
                        throw TranslationCoreError.invalidResponse("OpenAI-compatible 接口没有返回 HTTP 响应。")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        let data = try await collect(bytes, limit: 8_192)
                        let message = String(data: data, encoding: .utf8) ?? "无响应正文"
                        throw TranslationCoreError.httpStatus(http.statusCode, message)
                    }

                    let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
                    if contentType.contains("text/event-stream") {
                        var combined = ""
                        for try await line in bytes.lines {
                            try Task.checkCancellation()
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard trimmed.hasPrefix("data:") else { continue }
                            let body = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            if body == "[DONE]" { break }
                            guard let data = body.data(using: .utf8),
                                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let choices = object["choices"] as? [[String: Any]],
                                  let first = choices.first else { continue }
                            let delta = (first["delta"] as? [String: Any])?["content"] as? String
                                ?? first["text"] as? String
                            if let delta, !delta.isEmpty {
                                combined += delta
                                continuation.yield(.delta(delta))
                            }
                        }
                        guard !combined.isEmpty else {
                            throw TranslationCoreError.invalidResponse("OpenAI-compatible 流式响应没有译文内容。")
                        }
                        continuation.yield(.completed(TranslationResult(
                            text: combined,
                            detectedLanguage: request.sourceLanguage,
                            targetLanguage: request.targetLanguage
                        )))
                    } else {
                        let data = try await collect(bytes, limit: 4_000_000)
                        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        let choices = object?["choices"] as? [[String: Any]]
                        let message = choices?.first?["message"] as? [String: Any]
                        let translated = message?["content"] as? String ?? choices?.first?["text"] as? String
                        guard let translated, !translated.isEmpty else {
                            throw TranslationCoreError.invalidResponse("OpenAI-compatible 响应中没有译文内容。")
                        }
                        continuation.yield(.replacement(translated))
                        continuation.yield(.completed(TranslationResult(
                            text: translated,
                            detectedLanguage: request.sourceLanguage,
                            targetLanguage: request.targetLanguage
                        )))
                    }
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

    private func endpointURL() throws -> URL {
        let raw = configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.user == nil, url.password == nil else {
            throw TranslationCoreError.invalidConfiguration("OpenAI-compatible Base URL 无效。")
        }
        let path = url.path.lowercased()
        if path.hasSuffix("/chat/completions") { return url }
        if path.hasSuffix("/v1") {
            url.appendPathComponent("chat/completions")
        } else {
            url.appendPathComponent("v1")
            url.appendPathComponent("chat/completions")
        }
        return url
    }

    private func collect(_ bytes: URLSession.AsyncBytes, limit: Int) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > limit {
                throw TranslationCoreError.invalidResponse("翻译接口响应过大。")
            }
        }
        return data
    }
}
