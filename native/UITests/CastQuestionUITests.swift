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
    func testSupplementFromSavedChartConfirmsAndShowsOriginalEvidence() {
        let app = launch()
        XCTAssertTrue(app.navigationBars["确认占问"].waitForExistence(timeout: 10))
        let originalEvent = app.descendants(matching: .any).matching(identifier: "cast.event.setup_qimen").firstMatch
        originalEvent.tap(); originalEvent.typeText("office lease")
        app.swipeUp()
        let confirm = app.buttons["cast.confirm"]
        reveal(confirm, app: app); XCTAssertTrue(confirm.isEnabled); confirm.tap()
        XCTAssertTrue(app.staticTexts["audit.cast.saved"].waitForExistence(timeout: 10))
        let supplement = app.buttons["cast.supplement.f4-ui-omission"]
        reveal(supplement, app: app); XCTAssertTrue(supplement.isHittable); supplement.tap()
        XCTAssertTrue(app.navigationBars["补充这次占问"].waitForExistence(timeout: 10))
        capture("f6b-supplement-confirmation", app: app)
        let event = app.descendants(matching: .any).matching(identifier: "cast.event.setup_qimen").firstMatch
        for _ in 0..<8 { if event.isHittable { break }; app.swipeDown() }
        event.tap(); event.typeText("lease signing details")
        app.swipeUp(); reveal(confirm, app: app)
        XCTAssertEqual(confirm.label, "确认补充并沿用原盘"); confirm.tap()
        let revised = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "这是对同一次占问的补充，沿用原盘")).firstMatch
        XCTAssertTrue(revised.waitForExistence(timeout: 10))
        capture("f6b-preserved-chart-result", app: app)
        let evidence = app.buttons["reading.evidence.bottom"]
        reveal(evidence, app: app); evidence.tap()
        XCTAssertTrue(app.navigationBars["计算依据"].waitForExistence(timeout: 5))
        let detail = app.staticTexts["六爻 · 原盘补充"].exists ? app.staticTexts["六爻 · 原盘补充"] : app.staticTexts["奇门 · 原盘补充"]
        reveal(detail, app: app); XCTAssertTrue(detail.exists)
        capture("f6b-source-and-supplement-evidence", app: app)
    }

    func testCancelAtAccessibilitySizeNeverCasts() {
        let app = launch(large: true)
        XCTAssertTrue(app.buttons["cast.cancel"].waitForExistence(timeout: 10))
        capture("f6-accessibility-cancel", app: app)
        app.buttons["cast.cancel"].tap()
        XCTAssertTrue(app.staticTexts["audit.cast.cancelled"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["audit.cast.saved"].exists)
    }

    func testTimingRequiresExplicitFocusUnitAndEndDateBeforeSaving() {
        let app = launch()
        XCTAssertTrue(app.navigationBars["确认占问"].waitForExistence(timeout: 10))
        let event = app.descendants(matching: .any).matching(identifier: "cast.event.setup_qimen").firstMatch
        event.tap(); event.typeText("job application response")
        app.swipeUp()
        let toggle = app.switches["cast.timing.enabled"]
        reveal(toggle, app: app)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset:CGVector(dx:0.92,dy:0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        let confirm = app.buttons["cast.confirm"]
        reveal(confirm, app: app)
        XCTAssertFalse(confirm.isEnabled)
        let focus = app.buttons["cast.timing.focus"]
        for _ in 0..<8 { if focus.isHittable { break }; app.swipeDown() }
        focus.tap(); app.buttons["我自己"].tap()
        let unit = app.buttons["cast.timing.unit"]
        reveal(unit, app: app); unit.tap(); app.buttons["日"].tap()
        let end = app.textFields["cast.timing.end"]
        reveal(end, app: app); end.tap(); end.typeText("2099-12-31")
        app.swipeUp(); reveal(confirm, app: app)
        XCTAssertTrue(confirm.isEnabled)
        capture("timing-explicit-inputs", app: app)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["audit.cast.saved"].waitForExistence(timeout: 10))
        let supplement = app.buttons["cast.supplement.f4-ui-omission"]
        reveal(supplement, app: app); supplement.tap()
        XCTAssertTrue(app.navigationBars["补充这次占问"].waitForExistence(timeout: 10))
        // A new supplement requires its own opt-in; it cannot silently inherit
        // the previous question's date request as a fresh user instruction.
        reveal(toggle, app: app)
        XCTAssertEqual(toggle.value as? String, "0")
        app.buttons["cast.cancel"].tap()
    }
}
