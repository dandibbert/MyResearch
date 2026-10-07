import Foundation

public enum TranslationJSONPath {
    public static func value(at path: String, in root: Any) throws -> Any {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "$" else {
            throw TranslationCoreError.invalidConfiguration("JSON Path 必须以 $ 开头。")
        }
        var current: Any = root
        var index = trimmed.index(after: trimmed.startIndex)

        while index < trimmed.endIndex {
            switch trimmed[index] {
            case ".":
                index = trimmed.index(after: index)
                let start = index
                while index < trimmed.endIndex, trimmed[index] != ".", trimmed[index] != "[" {
                    index = trimmed.index(after: index)
                }
                let key = String(trimmed[start..<index])
                guard !key.isEmpty, let dictionary = current as? [String: Any], let next = dictionary[key] else {
                    throw TranslationCoreError.invalidResponse("响应中找不到 JSON Path：\(trimmed)")
                }
                current = next
            case "[":
                guard let close = trimmed[index...].firstIndex(of: "]") else {
                    throw TranslationCoreError.invalidConfiguration("JSON Path 缺少 ]。")
                }
                var token = String(trimmed[trimmed.index(after: index)..<close])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if (token.hasPrefix("\"") && token.hasSuffix("\"")) || (token.hasPrefix("'") && token.hasSuffix("'")) {
                    token.removeFirst()
                    token.removeLast()
                    guard let dictionary = current as? [String: Any], let next = dictionary[token] else {
                        throw TranslationCoreError.invalidResponse("响应中找不到 JSON Path：\(trimmed)")
                    }
                    current = next
                } else {
                    guard let offset = Int(token), let array = current as? [Any], array.indices.contains(offset) else {
                        throw TranslationCoreError.invalidResponse("响应中找不到 JSON Path：\(trimmed)")
                    }
                    current = array[offset]
                }
                index = trimmed.index(after: close)
            default:
                throw TranslationCoreError.invalidConfiguration("JSON Path 格式无效：\(trimmed)")
            }
        }
        return current
    }

    public static func string(at path: String, in root: Any) throws -> String {
        let value = try value(at: path, in: root)
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        throw TranslationCoreError.invalidResponse("JSON Path 指向的值不是文字。")
    }
}
