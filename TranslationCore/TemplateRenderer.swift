import Foundation

public struct TranslationTemplateValues: Equatable, Sendable {
    public var text: String
    public var from: String
    public var to: String
    public var credential: String

    public init(text: String, from: String, to: String, credential: String = "") {
        self.text = text
        self.from = from
        self.to = to
        self.credential = credential
    }
}

public enum TranslationTemplateRenderer {
    private static let allowedTokens = ["text", "from", "to", "credential"]
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    public static func renderURL(_ template: String, values: TranslationTemplateValues) throws -> String {
        try render(template, values: values) { value in
            guard let encoded = value.addingPercentEncoding(withAllowedCharacters: unreserved) else {
                throw TranslationCoreError.invalidTemplate("无法编码翻译模板中的动态值。")
            }
            return encoded
        }
    }

    public static func renderText(_ template: String, values: TranslationTemplateValues) throws -> String {
        try render(template, values: values) { $0 }
    }

    public static func renderHeaders(_ headers: [String: String], values: TranslationTemplateValues) throws -> [String: String] {
        var rendered: [String: String] = [:]
        for (name, value) in headers {
            guard !name.isEmpty, !name.contains("\n"), !name.contains("\r") else {
                throw TranslationCoreError.invalidTemplate("Header 名称无效。")
            }
            let output = try renderText(value, values: values)
            guard !output.contains("\n"), !output.contains("\r") else {
                throw TranslationCoreError.invalidTemplate("Header 值不能包含换行。")
            }
            rendered[name] = output
        }
        return rendered
    }

    public static func renderBody(
        encoding: HTTPBodyEncoding,
        template: String,
        values: TranslationTemplateValues
    ) throws -> Data? {
        switch encoding {
        case .none:
            return nil
        case .raw:
            return Data(try renderText(template, values: values).utf8)
        case .form:
            return Data(try renderURL(template, values: values).utf8)
        case .json:
            guard !template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let data = Data(template.utf8)
            let object: Any
            do {
                object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            } catch {
                throw TranslationCoreError.invalidTemplate("JSON Body 模板不是有效 JSON。")
            }
            let rendered = try renderJSONValue(object, values: values)
            do {
                return try JSONSerialization.data(withJSONObject: rendered, options: [.sortedKeys, .fragmentsAllowed])
            } catch {
                throw TranslationCoreError.invalidTemplate("无法生成 JSON Body。")
            }
        }
    }

    private static func renderJSONValue(_ value: Any, values: TranslationTemplateValues) throws -> Any {
        if let string = value as? String { return try renderText(string, values: values) }
        if let array = value as? [Any] { return try array.map { try renderJSONValue($0, values: values) } }
        if let dictionary = value as? [String: Any] {
            var output: [String: Any] = [:]
            for (key, item) in dictionary { output[key] = try renderJSONValue(item, values: values) }
            return output
        }
        return value
    }

    private static func render(
        _ template: String,
        values: TranslationTemplateValues,
        transform: (String) throws -> String
    ) throws -> String {
        try validateTokens(in: template)
        let replacements = [
            "text": values.text,
            "from": values.from,
            "to": values.to,
            "credential": values.credential,
        ]
        var output = template
        for token in allowedTokens {
            output = output.replacingOccurrences(of: "{\(token)}", with: try transform(replacements[token] ?? ""))
        }
        return output
    }

    private static func validateTokens(in template: String) throws {
        let regex = try NSRegularExpression(pattern: #"\{([A-Za-z][A-Za-z0-9_-]*)\}"#)
        let ns = template as NSString
        for match in regex.matches(in: template, range: NSRange(location: 0, length: ns.length)) {
            guard match.numberOfRanges > 1 else { continue }
            let token = ns.substring(with: match.range(at: 1))
            guard allowedTokens.contains(token) else {
                throw TranslationCoreError.invalidTemplate("不支持占位符 {\(token)}。")
            }
        }
    }
}
