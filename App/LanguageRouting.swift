import Foundation
import NaturalLanguage

enum TranslationLanguageRouter {
    static func route(_ text: String) -> (source: String, target: String) {
        let source = detect(text) ?? "auto"
        return (source, source.lowercased().hasPrefix("zh") ? "en" : "zh")
    }

    static func detect(_ text: String) -> String? {
        let sample = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sample.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(sample.prefix(2_000)))
        guard let language = recognizer.dominantLanguage else { return nil }
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        guard (hypotheses[language] ?? 0) >= 0.35 else { return nil }
        return language.rawValue
    }

    static func displayName(_ code: String) -> String {
        switch code.lowercased() {
        case "auto": return "自动"
        case "zh", "zh-hans": return "中文"
        case "zh-hant": return "繁中"
        case "en": return "English"
        case "ja": return "日本語"
        case "ko": return "한국어"
        case "fr": return "Français"
        case "de": return "Deutsch"
        case "es": return "Español"
        default: return code
        }
    }
}
