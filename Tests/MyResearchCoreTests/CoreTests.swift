import XCTest
import TranslationCore
@testable import MyResearchCore

final class CoreTests: XCTestCase {
    func testAllPresetsAreValid() throws {
        try ConfigurationCodec.validate(Configuration(targets: Presets.all, settings: AppSettings()))
    }
    func testReservedCharactersAreOneQueryValue() throws {
        let term = "春莱布 A&B + C/#? 🐈"
        let url = try TemplateEngine.url(template: "https://example.com/?q={query}&tab=all", query: term)
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.queryItems?.count, 2)
        XCTAssertEqual(parts.queryItems?.first?.value, term)
        XCTAssertNil(parts.fragment)
        XCTAssertTrue(url.absoluteString.contains("%2B"))
        XCTAssertTrue(url.absoluteString.contains("%2F"))
    }
    func testMultiplePlaceholdersAndPath() throws {
        let url = try TemplateEngine.url(template: "someapp://search/{query}?q={query}", query: "a/b")
        XCTAssertEqual(url.absoluteString, "someapp://search/a%2Fb?q=a%2Fb")
    }
    func testFixedAction() throws {
        XCTAssertEqual(try TemplateEngine.url(template: "exampleapp://home", query: "").absoluteString, "exampleapp://home")
    }
    func testInvalidTemplates() {
        for template in ["javascript:{query}", "file:///tmp/{query}", "data:{query}", "myresearch://search?q={query}", "https://", "https://example.com/{unknown}", "https://example.com/ space", "https://example.com/%ZZ", "https://user:pass@example.com?q={query}"] {
            XCTAssertThrowsError(try TemplateEngine.url(template: template, query: "text"), template)
        }
        XCTAssertThrowsError(try TemplateEngine.url(template: "https://example.com?q={query}", query: "  "))
    }
    func testPrefixTrigger() {
        XCTAssertEqual(SearchRouter.intent(for: "B 春莱布", configuration: .initial), SearchIntent(query: "春莱布", targetID: "bilibili"))
    }
    func testSuffixTrigger() {
        XCTAssertEqual(SearchRouter.intent(for: " 春莱布  xhs  ", configuration: .initial), SearchIntent(query: "春莱布", targetID: "xiaohongshu"))
    }
    func testTriggerPreservesInternalSpaces() {
        XCTAssertEqual(SearchRouter.intent(for: "g one  two", configuration: .initial).query, "one  two")
    }
    func testNoTriggerForSubstringOrSingleWord() {
        for text in ["b", "hello bilibili", "abc", "春莱布b", "billy cat"] {
            XCTAssertNil(SearchRouter.intent(for: text, configuration: .initial).targetID)
        }
    }
    func testDisabledLightningOrTarget() {
        var config = Configuration.initial
        config.settings.lightning = false
        XCTAssertNil(SearchRouter.intent(for: "b cat", configuration: config).targetID)
        config.settings.lightning = true
        config.targets[1].enabled = false
        XCTAssertNil(SearchRouter.intent(for: "b cat", configuration: config).targetID)
    }
    func testDefaultFallback() {
        var config = Configuration.initial
        config.targets.removeFirst()
        XCTAssertEqual(config.defaultTarget?.id, "bilibili")
        config.targets = []
        XCTAssertNil(config.defaultTarget)
    }
    func testConfigurationRoundtrip() throws {
        var original = Configuration.initial
        original.targets.reverse()
        original.settings.provider = .off
        XCTAssertEqual(try ConfigurationCodec.decode(ConfigurationCodec.encode(original)), original)
    }
    func testDuplicateIDsAndAliasesRejected() {
        var config = Configuration.initial
        config.targets.append(config.targets[0])
        XCTAssertThrowsError(try ConfigurationCodec.validate(config))
        config = .initial
        config.targets[1].aliases = ["G"]
        XCTAssertThrowsError(try ConfigurationCodec.validate(config))
    }
    func testInvalidVersionAndOversizeRejected() {
        var config = Configuration.initial
        config.schemaVersion = 3
        XCTAssertThrowsError(try ConfigurationCodec.validate(config))
        XCTAssertThrowsError(try ConfigurationCodec.decode(Data(repeating: 1, count: 2_000_001)))
        XCTAssertThrowsError(try ConfigurationCodec.decode(Data("{}".utf8)))
    }
    func testSuggestionsExcludeOriginalAndDuplicates() {
        XCTAssertEqual(SuggestionLogic.clean(["春莱布", "春莱布年龄", "春莱布年龄", "  ", "春莱布性别"], query: "春莱布", limit: 6), ["春莱布年龄", "春莱布性别"])
        XCTAssertEqual(SuggestionLogic.clean(["CAT", "cat food", "cat food"], query: "cat", limit: 3), ["cat food"])
    }
    func testSuggestionsParser() throws {
        let data = Data("[\"cat\", [\"cat food\", \"cat toy\"], [], {}]".utf8)
        XCTAssertEqual(try SuggestionLogic.parse(data), ["cat food", "cat toy"])
        XCTAssertThrowsError(try SuggestionLogic.parse(Data("{}".utf8)))
    }
    func testLocalHistoryAndCap() {
        var history: [HistoryItem] = []
        for i in 0..<150 { history = SuggestionLogic.recording(history, query: "cat \(i)", targetID: "google") }
        XCTAssertEqual(history.count, 100)
        history = SuggestionLogic.recording(history, query: "cat 149", targetID: "google")
        XCTAssertEqual(history.count, 100)
        XCTAssertEqual(history.first?.query, "cat 149")
        XCTAssertEqual(SuggestionLogic.local(history, query: "cat", limit: 3).count, 3)
    }
    func testQuickTargetsRespectManualOrder() {
        var config = Configuration.initial
        config.targets.reverse()
        XCTAssertEqual(config.quickTargets.map(\.id), ["youtube", "baidu", "bing", "xiaohongshu", "bilibili", "google"])
    }
    func testLegacyConfigurationWithoutSafariFieldsStillDecodes() throws {
        let legacy = """
        {
          "schemaVersion": 1,
          "targets": [{
            "id": "google", "name": "Google", "symbol": "globe", "tintHex": "4285F4",
            "template": "https://www.google.com/search?q={query}", "fallbackTemplate": "",
            "aliases": ["g"], "enabled": true, "quickAccess": true
          }],
          "settings": {
            "autoFocus": true, "thumbLayout": true, "lightning": true,
            "provider": "off", "historyEnabled": true, "maxSuggestions": 6,
            "defaultTargetID": "google"
          }
        }
        """
        let config = try ConfigurationCodec.decode(Data(legacy.utf8))
        XCTAssertEqual(config.schemaVersion, 2)
        XCTAssertEqual(config.targets[0].kind, .link)
        XCTAssertTrue(config.settings.usesInAppSafari)
        XCTAssertFalse(config.targets[0].usesInAppSafari)
        XCTAssertEqual(config.quickTargets.map(\.id), ["google"])
    }
    func testTranslatorSourceRoundtripAndTrigger() throws {
        let translatorID = "translator-test"
        let translator = TranslationConfiguration(
            engine: .http,
            openAI: nil,
            http: HTTPTranslationConfiguration(
                method: "POST",
                url: "https://example.com/translate",
                headers: ["Authorization": "Bearer {credential}"],
                bodyEncoding: .json,
                bodyTemplate: #"{"text":"{text}","source":"{from}","target":"{to}"}"#,
                responseJSONPath: "$.translation"
            ),
            credentialID: "translator.test",
            autoRun: true
        )
        var config = Configuration.initial
        config.targets.append(SearchTarget(
            id: translatorID,
            name: "Test Translator",
            symbol: "character.book.closed.fill",
            template: "",
            aliases: ["tr"],
            kind: .translator,
            translator: translator
        ))
        let decoded = try ConfigurationCodec.decode(ConfigurationCodec.encode(config))
        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.enabledTranslators.map(\.id), [translatorID])
        XCTAssertEqual(decoded.defaultTarget?.id, "google")
        XCTAssertEqual(SearchRouter.intent(for: "tr hello", configuration: decoded).targetID, translatorID)
    }

    func testTextInsertionUsesCaretAndUTF16Selection() {
        let caret = TextInsertion.inserting("{query}", into: "https://x.test?q=&lang=zh", selection: NSRange(location: 17, length: 0))
        XCTAssertEqual(caret.text, "https://x.test?q={query}&lang=zh")
        XCTAssertEqual(caret.selection.location, 24)

        let source = "猫🐈dog" as NSString
        let catRange = source.range(of: "🐈")
        let replaced = TextInsertion.inserting("{query}", into: source as String, selection: catRange)
        XCTAssertEqual(replaced.text, "猫{query}dog")
        XCTAssertEqual(replaced.selection.location, 8)
    }

}
