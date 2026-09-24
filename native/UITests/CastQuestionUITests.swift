import XCTest

final class CastQuestionUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--cast-confirmation-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication, towardTop: Bool = false) {
        // The system keyboard (including its candidate bar) is not form
        // content. App-wide swipes/taps can hit it while AX still reports an
        // obscured form switch as hittable. Scroll within the visible form.
        for _ in 0..<10 {
            let screen = app.frame
            let top = app.navigationBars.allElementsBoundByIndex.map { $0.frame.maxY }.max() ?? screen.minY
            let keyboard = app.keyboards.firstMatch
            let bottom = keyboard.exists ? keyboard.frame.minY - 60 : screen.maxY - 34
            let target = element.exists ? element.frame : .zero
            if element.exists && element.isHittable && target.minY >= top + 8 && target.maxY <= bottom { return }
            let down = target.isEmpty ? towardTop : target.midY < top + 8
            let height = max(80, bottom - top - 16)
            let startY = top + 8 + height * (down ? 0.2 : 0.8)
            let endY = top + 8 + height * (down ? 0.8 : 0.2)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            // The right side contains switches. An iOS 18 drag beginning on
            // one can toggle an unrelated option; use the Form's outer gutter.
            origin.withOffset(CGVector(dx: screen.width * 0.03, dy: startY))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: screen.width * 0.03, dy: endY)))
        }
        XCTAssertTrue(element.exists && element.isHittable, "The actual form control must be reachable")
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
        reveal(event, app: app, towardTop: true)
        XCTAssertTrue(event.exists)
        event.tap(); event.typeText("sign office lease")
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
        let confirm = app.buttons["cast.confirm"]
        reveal(confirm, app: app); XCTAssertTrue(confirm.isEnabled); confirm.tap()
        XCTAssertTrue(app.staticTexts["audit.cast.saved"].waitForExistence(timeout: 10))
        let supplement = app.buttons["cast.supplement.f4-ui-omission"]
        reveal(supplement, app: app); XCTAssertTrue(supplement.isHittable); supplement.tap()
        XCTAssertTrue(app.navigationBars["补充这次占问"].waitForExistence(timeout: 10))
        capture("f6b-supplement-confirmation", app: app)
        let event = app.descendants(matching: .any).matching(identifier: "cast.event.setup_qimen").firstMatch
        reveal(event, app: app, towardTop: true)
        event.tap(); event.typeText("lease signing details")
        reveal(confirm, app: app)
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

    func testCancelNeverCasts() {
        let app = launch()
        XCTAssertTrue(app.buttons["cast.cancel"].waitForExistence(timeout: 10))
        capture("f6-cancel", app: app)
        app.buttons["cast.cancel"].tap()
        XCTAssertTrue(app.staticTexts["audit.cast.cancelled"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["audit.cast.saved"].exists)
    }

    func testSpecialSelectionRequiresOptInAndIsReconfirmedForSupplement() {
        let app = launch()
        XCTAssertTrue(app.navigationBars["确认占问"].waitForExistence(timeout: 10))
        let event = app.descendants(matching: .any).matching(identifier: "cast.event.setup_qimen").firstMatch
        event.tap(); event.typeText("rain at the office site")
        let toggle = app.switches["cast.selection.enabled"]
        reveal(toggle, app: app)
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let confirm = app.buttons["cast.confirm"]
        reveal(confirm, app: app); XCTAssertFalse(confirm.isEnabled)
        let focus = app.buttons["cast.selection.focus"]
        reveal(focus, app: app, towardTop: true)
        focus.tap(); app.buttons["降雨"].tap()
        reveal(confirm, app: app); XCTAssertTrue(confirm.isEnabled)
        capture("selection-weather-confirmed", app: app)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["audit.cast.saved"].waitForExistence(timeout: 10))
        let supplement = app.buttons["cast.supplement.f4-ui-omission"]
        reveal(supplement, app: app); supplement.tap()
        XCTAssertTrue(app.navigationBars["补充这次占问"].waitForExistence(timeout: 10))
        reveal(toggle, app: app)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        // The proposed focus is visible, but a new supplement requires opt-in.
        reveal(confirm, app: app); XCTAssertTrue(confirm.isEnabled); confirm.tap()
        let revised = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "这是对同一次占问的补充，沿用原盘")).firstMatch
        XCTAssertTrue(revised.waitForExistence(timeout: 10))
        XCTAssertTrue(revised.label.contains("天柱"))
        XCTAssertTrue(revised.label.contains("天蓬"))
        capture("selection-original-chart-supplement", app: app)
    }

    func testTimingRequiresExplicitFocusUnitAndEndDateBeforeSaving() {
        let app = launch()
        XCTAssertTrue(app.navigationBars["确认占问"].waitForExistence(timeout: 10))
        let event = app.descendants(matching: .any).matching(identifier: "cast.event.setup_qimen").firstMatch
        event.tap(); event.typeText("job application response")
        let toggle = app.switches["cast.timing.enabled"]
        reveal(toggle, app: app)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset:CGVector(dx:0.92,dy:0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        let confirm = app.buttons["cast.confirm"]
        reveal(confirm, app: app)
        XCTAssertFalse(confirm.isEnabled)
        let focus = app.buttons["cast.timing.focus"]
        reveal(focus, app: app, towardTop: true)
        focus.tap(); app.buttons["我自己"].tap()
        let unit = app.buttons["cast.timing.unit"]
        reveal(unit, app: app, towardTop: true); unit.tap(); app.buttons["日"].tap()
        let end = app.textFields["cast.timing.end"]
        reveal(end, app: app); end.tap(); end.typeText("2099-12-31")
        reveal(confirm, app: app)
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
