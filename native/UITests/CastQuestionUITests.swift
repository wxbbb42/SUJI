import XCTest

final class CastQuestionUITests: XCTestCase {
    private func launch(large: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--cast-confirmation-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<10 { if element.isHittable { return }; app.swipeUp() }
    }
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testMissingEventMustBeEditedBeforeActualCast() {
        let app = launch()
        XCTAssertTrue(app.navigationBars["确认占问"].waitForExistence(timeout: 10))
        capture("f6-missing-event", app: app)
        let confirm = app.buttons["cast.confirm"]
        reveal(confirm, app: app)
        XCTAssertFalse(confirm.isEnabled)
        let event = app.descendants(matching: .any).matching(identifier: "cast.event.setup_qimen").firstMatch
        for _ in 0..<8 { if event.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(event.exists)
        event.tap(); event.typeText("sign office lease")
        app.swipeUp()
        reveal(confirm, app: app)
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["audit.cast.saved"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["audit.cast.saved"].label.contains("sign office lease"))
        capture("f6-confirmed-actual-engine", app: app)
    }
    func testCancelAtAccessibilitySizeNeverCasts() {
        let app = launch(large: true)
        XCTAssertTrue(app.buttons["cast.cancel"].waitForExistence(timeout: 10))
        capture("f6-accessibility-cancel", app: app)
        app.buttons["cast.cancel"].tap()
        XCTAssertTrue(app.staticTexts["audit.cast.cancelled"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["audit.cast.saved"].exists)
    }
}
