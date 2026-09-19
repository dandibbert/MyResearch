import XCTest

/// Exercises the actual installed .appex through the system share sheet.
final class ShareExtensionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        XCUIApplication(bundleIdentifier: "com.dandibbert.MyResearch.ShareProbe").terminate()
    }
    override func tearDownWithError() throws {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "share-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func present(_ text: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--share-fixture", "--query=\(text)", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["system-share-test"].waitForExistence(timeout: 8))
        let tip = app.buttons["Continue"]
        if tip.waitForExistence(timeout: 1), tip.isHittable { tip.tap() }
        else if app.buttons["继续"].exists, app.buttons["继续"].isHittable { app.buttons["继续"].tap() }
        app.buttons["toggle-keyboard"].tap()
        app.buttons["system-share-test"].tap()
        // UIActivityViewController exposes its horizontal activities as cells,
        // not buttons. Match the actual system accessibility tree.
        let extensionCell = app.cells.matching(NSPredicate(format: "label == %@", "MyResearch")).firstMatch
        if !extensionCell.waitForExistence(timeout: 4) {
            let more = app.cells.matching(NSPredicate(format: "label IN %@", ["更多", "More"])).firstMatch
            if more.exists { more.tap() }
        }
        XCTAssertTrue(extensionCell.waitForExistence(timeout: 5), app.debugDescription)
        extensionCell.tap()
        XCTAssertTrue(app.buttons["share-done"].waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.buttons["share-target-share-probe"].waitForExistence(timeout: 6), "Shared configuration did not cross into the real extension: \(app.debugDescription)")
        return app
    }
    func testSharedConfigurationAndSelectedTextWinOverURL() {
        let app = present("春莱布 A&B + 🐈")
        let field = app.textFields["share-input"]
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        expectation(for: NSPredicate(format: "value == %@", "春莱布 A&B + 🐈"), evaluatedWith: field)
        waitForExpectations(timeout: 6)
        XCTAssertTrue(app.buttons["share-original"].isHittable)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "已同步主 App")).firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "share-extension-ready"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["share-done"].tap()
        XCTAssertTrue(app.buttons["system-share-test"].waitForExistence(timeout: 5))
    }
    func testActualExtensionOpensExternalSchemeAndStripsTrigger() {
        let app = present("probe 春莱布 & + 🐈")
        let target = app.buttons["share-target-share-probe"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: target)
        waitForExpectations(timeout: 6)
        target.tap()
        let destination = XCUIApplication(bundleIdentifier: "com.dandibbert.MyResearch.ShareProbe")
        XCTAssertTrue(destination.wait(for: .runningForeground, timeout: 8), "The extension must REALLY open another application.")
        let value = destination.staticTexts["received-share-url"]
        XCTAssertTrue(value.waitForExistence(timeout: 3))
        let url = URLComponents(string: value.label)
        XCTAssertEqual(url?.queryItems?.first(where: { $0.name == "q" })?.value, "春莱布 & + 🐈")
    }
    func testQuickButtonOverridesGoogleDefault() {
        let app = present("原词快捷按钮")
        let field = app.textFields["share-input"]
        expectation(for: NSPredicate(format: "value == %@", "原词快捷按钮"), evaluatedWith: field)
        waitForExpectations(timeout: 6)
        app.buttons["share-quick-share-probe"].tap()
        let destination = XCUIApplication(bundleIdentifier: "com.dandibbert.MyResearch.ShareProbe")
        XCTAssertTrue(destination.wait(for: .runningForeground, timeout: 8))
        let value = destination.staticTexts["received-share-url"]
        XCTAssertTrue(value.waitForExistence(timeout: 3))
        XCTAssertEqual(URLComponents(string: value.label)?.queryItems?.first?.value, "原词快捷按钮")
    }
    func testUnavailableAppKeepsExtensionAndShowsRecovery() {
        let app = present("不会丢失的原词")
        let target = app.buttons["share-target-share-missing"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: target)
        waitForExpectations(timeout: 6)
        target.tap()
        XCTAssertTrue(app.otherElements["share-notice"].waitForExistence(timeout: 8) || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "系统没有确认跳转")).firstMatch.exists)
        XCTAssertTrue(app.buttons["share-done"].exists)
        XCTAssertEqual(app.textFields["share-input"].value as? String, "不会丢失的原词")
    }
}
