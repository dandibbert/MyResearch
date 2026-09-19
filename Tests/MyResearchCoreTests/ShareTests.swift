import XCTest
@testable import MyResearchCore

final class ShareTests: XCTestCase {
    func testSafariSelectionBeatsTextAndPageURL() {
        XCTAssertEqual(SharedInputResolver.resolve(selection: [" 春莱布 "], texts: ["page title"], urls: ["https://example.com"]).text, "春莱布")
    }
    func testTextBeatsURLRegardlessOfProviderOrder() {
        XCTAssertEqual(SharedInputResolver.resolve(texts: ["猫 & 犬"], urls: ["https://example.com"]).text, "猫 & 犬")
    }
    func testEmptySelectionFallsBackToTextThenURL() {
        XCTAssertEqual(SharedInputResolver.resolve(selection: ["\n"], texts: ["text"]).text, "text")
        XCTAssertEqual(SharedInputResolver.resolve(urls: ["https://example.com"]).text, "https://example.com")
        XCTAssertEqual(SharedInputResolver.resolve().text, "")
    }
    func testInputBoundPreservesGraphemesAndSignalsTruncation() {
        let value = SharedInputResolver.resolve(texts: [String(repeating: "👨‍👩‍👧‍👦", count: 4097)])
        XCTAssertEqual(value.text.count, 4096)
        XCTAssertTrue(value.wasTruncated)
        XCTAssertFalse(SharedInputResolver.resolve(texts: ["abc"]).wasTruncated)
    }
    func testHandoffRoundTripsReservedCharactersWithoutParameterInjection() throws {
        let input = ShareHandoff(query: "春莱布 &run=1 + # ? / 🐈", targetID: "hello & world", run: false)
        XCTAssertEqual(ShareHandoff.parse(try input.url()), input)
        XCTAssertFalse(ShareHandoff.parse(try input.url())!.run)
    }
    func testHandoffRunAndTarget() throws {
        let input = ShareHandoff(query: "probe 猫", targetID: "share-probe", run: true)
        XCTAssertEqual(ShareHandoff.parse(try input.url()), input)
        XCTAssertEqual(ShareHandoff.parse(URL(string: "myresearch://search?q=cat&run=1")!)?.query, "cat")
    }
    func testRejectsMalformedHandoff() {
        for value in ["https://share?q=x", "myresearch://unknown?q=x", "myresearch://share", "myresearch://share?q=x&q=y", "myresearch://share?q=x&target=a&target=b", "myresearch://share?q=x&run=1&run=0", "myresearch://user:pass@share?q=x", "myresearch://share:123?q=x", "myresearch://share/path?q=x"] {
            XCTAssertNil(ShareHandoff.parse(URL(string: value)!), value)
        }
    }
    func testOversizedHandoffRejected() throws {
        let input = ShareHandoff(query: String(repeating: "x", count: 4097), targetID: nil, run: false)
        XCTAssertThrowsError(try input.url())
        XCTAssertNil(ShareHandoff.parse(URL(string: "myresearch://share?q=" + input.query)!))
    }
    func testSharedSnapshotPreservesEntireConfiguration() throws {
        var config = Configuration.initial
        config.targets.reverse()
        config.targets[1].enabled = false
        config.settings.defaultTargetID = "bilibili"
        config.settings.provider = .off
        let snapshot = ConfigurationSnapshot(configuration: config)
        XCTAssertEqual(try ConfigurationSnapshot.decode(JSONEncoder().encode(snapshot)).configuration, config)
    }
    func testInvalidSharedSnapshotRejected() throws {
        var snapshot = ConfigurationSnapshot(configuration: .initial)
        snapshot.configuration.targets.append(snapshot.configuration.targets[0])
        XCTAssertThrowsError(try ConfigurationSnapshot.decode(JSONEncoder().encode(snapshot)))
        XCTAssertThrowsError(try ConfigurationSnapshot.decode(Data(repeating: 0, count: 2_100_001)))
    }
}
