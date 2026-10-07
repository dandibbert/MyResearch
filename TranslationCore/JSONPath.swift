import Foundation

public enum TranslationJSONPath {
    private enum Component {
        case key(String)
        case index(Int)
        case wildcard
    }

    public static func value(at path: String, in root: Any) throws -> Any {
        let components = try parse(path)
        var nodes: [Any] = [root]

        for component in components {
            var next: [Any] = []
            for node in nodes {
                switch component {
                case .key(let key):
                    guard let dictionary = node as? [String: Any], let value = dictionary[key] else { continue }
                    next.append(value)
                case .index(let index):
                    guard let array = node as? [Any], array.indices.contains(index) else { continue }
                    next.append(array[index])
                case .wildcard:
                    guard let array = node as? [Any] else { continue }
                    next.append(contentsOf: array)
                }
            }
            guard !next.isEmpty else {
                throw TranslationCoreError.invalidResponse("响应中找不到 JSON Path：\(path)")
            }
            nodes = next
        }

        return nodes.count == 1 ? nodes[0] : nodes
    }

    public static func string(at path: String, in root: Any) throws -> String {
        let value = try value(at: path, in: root)
        let strings = flattenStrings(value)
        guard !strings.isEmpty else {
            throw TranslationCoreError.invalidResponse("JSON Path 指向的值不是文字。")
        }
        return strings.joined()
    }

    private static func flattenStrings(_ value: Any) -> [String] {
        if let text = value as? String { return [text] }
        if let number = value as? NSNumber { return [number.stringValue] }
        if let array = value as? [Any] { return array.flatMap(flattenStrings) }
        return []
    }

    private static func parse(_ path: String) throws -> [Component] {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "$" else {
            throw TranslationCoreError.invalidConfiguration("JSON Path 必须以 $ 开头。")
        }

        var result: [Component] = []
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
                guard !key.isEmpty else {
                    throw TranslationCoreError.invalidConfiguration("JSON Path 字段名不能为空。")
                }
                result.append(.key(key))

            case "[":
                guard let close = trimmed[index...].firstIndex(of: "]") else {
                    throw TranslationCoreError.invalidConfiguration("JSON Path 缺少 ]。")
                }
                var token = String(trimmed[trimmed.index(after: index)..<close])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if token == "*" {
                    result.append(.wildcard)
                } else if (token.first == "\"" && token.last == "\"") || (token.first == "'" && token.last == "'") {
                    token.removeFirst()
                    token.removeLast()
                    guard !token.isEmpty else {
                        throw TranslationCoreError.invalidConfiguration("JSON Path 字段名不能为空。")
                    }
                    result.append(.key(token))
                } else if let offset = Int(token), offset >= 0 {
                    result.append(.index(offset))
                } else {
                    throw TranslationCoreError.invalidConfiguration("JSON Path 索引无效：\(token)")
                }
                index = trimmed.index(after: close)

            default:
                throw TranslationCoreError.invalidConfiguration("JSON Path 格式无效：\(trimmed)")
            }
        }

        return result
    }
}
