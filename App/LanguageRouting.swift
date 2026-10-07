import Foundation
import NaturalLanguage

struct TranslationPairOption: Identifiable, Equatable {
    var source: String
    var target: String
    var id: String { source + "→" + target }

    var compactTitle: String {
        "\(TranslationLanguageRouter.shortName(source)) → \(TranslationLanguageRouter.shortName(target))"
    }
}

enum TranslationLanguageRouter {
    static let sourceLanguages = ["auto", "zh", "zh-Hant", "en", "ja", "ko", "fr", "de", "es"]
    static let targetLanguages = ["zh", "zh-Hant", "en", "ja", "ko", "fr", "de", "es"]

    static func route(
        _ text: String,
        preferredTarget: String? = nil,
        lastSource: String? = nil,
        lastTarget: String? = nil
    ) -> (source: String, target: String) {
        let source = detect(text) ?? "auto"

        if let preferredTarget,
           targetLanguages.contains(preferredTarget),
           preferredTarget != source {
            return (source, preferredTarget)
        }

        if source != "auto",
           lastSource == source,
           let lastTarget,
           targetLanguages.contains(lastTarget),
           lastTarget != source {
            return (source, lastTarget)
        }

        return (source, defaultTarget(for: source))
    }

    static func suggestedPairs(
        for text: String,
        selectedSource: String? = nil,
        preferredTarget: String? = nil,
        lastSource: String? = nil,
        lastTarget: String? = nil
    ) -> [TranslationPairOption] {
        let detected = detect(text)
        let source = selectedSource.flatMap { $0 == "auto" ? detected : $0 }
            ?? detected
            ?? (lastSource.flatMap { $0 == "auto" ? nil : $0 })
            ?? "auto"

        var targets: [String] = []
        func add(_ value: String?) {
            guard let value,
                  targetLanguages.contains(value),
                  value != source,
                  !targets.contains(value) else { return }
            targets.append(value)
        }

        add(preferredTarget)
        if lastSource == source { add(lastTarget) }

        for value in targetPriority(for: source) {
            add(value)
        }

        return targets.prefix(3).map { TranslationPairOption(source: source, target: $0) }
    }

    static func defaultTarget(for source: String) -> String {
        switch source.lowercased() {
        case "zh", "zh-hans", "zh-hant": return "ja"
        case "ja", "ko", "fr", "de", "es", "en": return "zh"
        default: return "zh"
        }
    }

    static func targetPriority(for source: String) -> [String] {
        switch source.lowercased() {
        case "ja": return ["zh", "en", "ko"]
        case "zh", "zh-hans", "zh-hant": return ["ja", "en", "ko"]
        case "en": return ["zh", "ja", "ko"]
        case "ko": return ["zh", "ja", "en"]
        case "fr", "de", "es": return ["zh", "en", "ja"]
        default: return ["zh", "en", "ja"]
        }
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
        case "auto": return "自动检测"
        case "zh", "zh-hans": return "中文"
        case "zh-hant": return "繁體中文"
        case "en": return "English"
        case "ja": return "日本語"
        case "ko": return "한국어"
        case "fr": return "Français"
        case "de": return "Deutsch"
        case "es": return "Español"
        default: return code
        }
    }

    static func shortName(_ code: String) -> String {
        switch code.lowercased() {
        case "auto": return "Auto"
        case "zh", "zh-hans": return "中"
        case "zh-hant": return "繁"
        case "en": return "英"
        case "ja": return "日"
        case "ko": return "韩"
        case "fr": return "法"
        case "de": return "德"
        case "es": return "西"
        default: return code.uppercased()
        }
    }
}
