import XCTest
@testable import TranslationCore

final class TranslationCoreTests: XCTestCase {
    func testURLTemplatePercentEncodesDynamicValues() throws {
        let values = TranslationTemplateValues(text: "猫 & + / #", from: "zh", to: "en", credential: "")
        let rendered = try TranslationTemplateRenderer.renderURL(
            "https://example.com/translate?q={text}&from={from}&to={to}",
            values: values
        )
        XCTAssertEqual(rendered, "https://example.com/translate?q=%E7%8C%AB%20%26%20%2B%20%2F%20%23&from=zh&to=en")
    }

    func testJSONBodyTemplateEscapesInsertedTextSafely() throws {
        let values = TranslationTemplateValues(text: #"他说："hello" \ world"#, from: "zh", to: "en", credential: "secret")
        let data = try XCTUnwrap(TranslationTemplateRenderer.renderBody(
            encoding: .json,
            template: #"{"text":"{text}","meta":{"to":"{to}"}}"#,
            values: values
        ))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["text"] as? String, values.text)
        XCTAssertEqual((object["meta"] as? [String: Any])?["to"] as? String, "en")
    }

    func testHeaderCredentialSubstitutionRejectsInjection() throws {
        let safe = try TranslationTemplateRenderer.renderHeaders(
            ["Authorization": "Bearer {credential}"],
            values: TranslationTemplateValues(text: "", from: "en", to: "zh", credential: "abc123")
        )
        XCTAssertEqual(safe["Authorization"], "Bearer abc123")

        XCTAssertThrowsError(try TranslationTemplateRenderer.renderHeaders(
            ["X-Key": "{credential}"],
            values: TranslationTemplateValues(text: "", from: "en", to: "zh", credential: "a\nInjected: yes")
        ))
    }

    func testJSONPathSupportsObjectsAndArrayIndexes() throws {
        let object = try JSONSerialization.jsonObject(with: Data(#"{"data":{"translations":[{"text":"hello"}]},"nested":[[["ok"]]]}"#.utf8))
        XCTAssertEqual(try TranslationJSONPath.string(at: "$.data.translations[0].text", in: object), "hello")
        XCTAssertEqual(try TranslationJSONPath.string(at: "$.nested[0][0][0]", in: object), "ok")
    }

    func testHTTPConfigurationValidation() throws {
        let config = TranslationConfiguration(
            engine: .http,
            openAI: nil,
            http: HTTPTranslationConfiguration(
                method: "POST",
                url: "https://example.com/api?to={to}",
                headers: ["X-Key": "{credential}"],
                bodyEncoding: .json,
                bodyTemplate: #"{"q":"{text}","from":"{from}"}"#,
                responseJSONPath: "$.result"
            ),
            credentialID: "translator.example"
        )
        XCTAssertNoThrow(try TranslationConfigurationValidator.validate(config))
    }

    func testUnknownPlaceholderRejected() {
        let values = TranslationTemplateValues(text: "x", from: "en", to: "zh")
        XCTAssertThrowsError(try TranslationTemplateRenderer.renderText("{unknown}", values: values))
    }
}
