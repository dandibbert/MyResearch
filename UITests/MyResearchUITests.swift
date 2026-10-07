import XCTest

final class MyResearchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }
    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }
    private func launch(_ query: String = "", extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--query=\(query)"] + extraArguments + ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.textFields["search-input"].waitForExistence(timeout: 8))
        // Fresh CI simulators may present the system QuickPath keyboard introduction.
        let introduction = app.buttons["Continue"]
        if introduction.waitForExistence(timeout: 1), introduction.isHittable { introduction.tap() }
        else if app.buttons["继续"].exists, app.buttons["继续"].isHittable { app.buttons["继续"].tap() }
        return app
    }
    private func shot(_ title: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = title
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testAutoKeyboardAndPinnedOriginal() {
        let app = launch("春莱布2")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 6))
        let original = app.buttons["original-query"]
        XCTAssertTrue(original.waitForExistence(timeout: 3))
        let before = original.frame.minY
        // Trigger a genuinely new asynchronous request after measuring the row.
        app.textFields["search-input"].typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual(app.textFields["search-input"].value as? String, "春莱布")
        XCTAssertTrue(app.buttons["candidate-春莱布 年龄"].waitForExistence(timeout: 6))
        XCTAssertEqual(original.frame.minY, before, accuracy: 1.0)
        XCTAssertTrue(original.isHittable)
        XCTAssertTrue(app.buttons["original-google"].isHittable)
        shot("01-search-keyboard-pinned-original")
    }
    func testExplicitQuickSourceOverridesDefault() {
        let app = launch("春莱布")
        app.buttons["original-xiaohongshu"].tap()
        let opened = app.staticTexts["last-opened-url"]
        XCTAssertTrue(opened.waitForExistence(timeout: 4))
        XCTAssertTrue(opened.label.contains("xiaohongshu.com/search_result?keyword="))
        XCTAssertTrue(opened.label.contains("%E6%98%A5"))
    }
    func testTriggerUsesTargetAndStripsAlias() {
        let app = launch("b Spring live")
        app.buttons["submit-search"].tap()
        let opened = app.staticTexts["last-opened-url"]
        XCTAssertTrue(opened.waitForExistence(timeout: 4))
        XCTAssertEqual(opened.label, "https://search.bilibili.com/all?keyword=Spring%20live")
    }
    func testLinkEditingSaves() {
        let app = launch()
        app.buttons["toggle-keyboard"].tap()
        XCTAssertTrue(app.buttons["tab-1"].waitForExistence(timeout: 4))
        app.buttons["tab-1"].tap()
        XCTAssertTrue(app.buttons["edit-google"].waitForExistence(timeout: 4))
        app.buttons["edit-google"].tap()
        let name = app.textFields["target-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 4))
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "My Google")
        app.buttons["save-target"].tap()
        XCTAssertTrue(app.buttons["edit-google"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["edit-google"].label.contains("My Google"))
        shot("02-my-links")
        app.buttons["tab-2"].tap()
        shot("03-settings")
    }
    func testQuickSourceStripScrollsToLaterManualOrderItems() {
        let app = launch("测试")
        let strip = app.scrollViews["original-sources"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        let youtube = app.buttons["original-youtube"]
        XCTAssertTrue(youtube.exists)
        if !youtube.isHittable { strip.swipeLeft() }
        XCTAssertTrue(youtube.isHittable)
        youtube.tap()
        let opened = app.staticTexts["last-opened-url"]
        XCTAssertTrue(opened.waitForExistence(timeout: 4))
        XCTAssertTrue(opened.label.contains("youtube.com/results"))
        shot("04-scrollable-quick-sources")
    }
    func testTranslatorTriggerOpensSmartPairLauncher() {
        let app = launch("tr こんにちは", extraArguments: ["--translation-fixture"])
        app.buttons["submit-search"].tap()

        XCTAssertTrue(app.navigationBars["翻译设置"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["translation-pair-ja-zh"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["translation-pair-ja-en"].exists)
        XCTAssertFalse(app.buttons["translation-pair-zh-ja"].exists)
        XCTAssertTrue(app.buttons["translation-launch-confirm"].isHittable)
        shot("05-translation-pair-launcher")
    }

    func testTranslatorEditorKeepsAdvancedOptionsCollapsed() {
        let app = launch(extraArguments: ["--translation-fixture"])
        app.buttons["toggle-keyboard"].tap()
        XCTAssertTrue(app.buttons["tab-1"].waitForExistence(timeout: 4))
        app.buttons["tab-1"].tap()
        XCTAssertTrue(app.buttons["edit-translator-fixture"].waitForExistence(timeout: 4))
        app.buttons["edit-translator-fixture"].tap()

        XCTAssertTrue(app.navigationBars["编辑翻译引擎"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["获取模型列表"].exists)
        XCTAssertTrue(app.buttons["高级设置"].exists)
        XCTAssertFalse(app.staticTexts["System Prompt"].exists)
        shot("06-translator-editor")
    }

    func testLandscapeKeepsInputReachable() {
        let app = launch("a long search query")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["original-query"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["original-query"].isHittable)
        XCTAssertTrue(app.textFields["search-input"].isHittable)
        shot("07-landscape-search")
    }
}
