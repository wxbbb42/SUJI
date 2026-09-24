import XCTest

/// Synthetic in-memory notebook only; no model requests or production account.
final class NatalReadingReportUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--notebook-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
    }
    private func launch() {
        app.launch()
        XCTAssertTrue(app.buttons["nav.profile"].waitForExistence(timeout: 15))
    }
    private func tap(_ id: String) {
        let button = app.notebookNavigationButton(id)
        if app.navigationBars["我的册页"].exists && id.hasPrefix("report.") {
            // LazyVStack need not expose lower modules to AX before scrolling.
            // Also keep the target's center below the overlaid navigation bar.
            for _ in 0..<14 {
                let top = app.navigationBars["我的册页"].frame.maxY + 4
                if button.exists && button.isHittable && button.frame.minY >= top && button.frame.maxY <= app.frame.maxY - 34 { break }
                let scroll = app.scrollViews["report.scroll"]
                if button.exists && button.frame.midY < top { scroll.swipeDown(velocity: .slow) }
                else { scroll.swipeUp(velocity: .slow) }
            }
        } else {
            XCTAssertTrue(button.waitForExistence(timeout: 15), id)
            for _ in 0..<9 { if button.isHittable { break }; app.swipeUp() }
        }
        XCTAssertTrue(button.isHittable, id); button.tap()
    }
    private func createSyntheticDossier() {
        tap("profile.addBirth")
        XCTAssertTrue(app.buttons["birth.save"].waitForExistence(timeout: 8))
        let confirm = app.switches["birth.confirm"]
        for _ in 0..<8 { if confirm.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(confirm.exists && confirm.isHittable)
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        tap("birth.save")
        XCTAssertTrue(app.staticTexts["profile.dossierReady"].waitForExistence(timeout: 30))
    }
    private func openReport() {
        // Dossier readiness can be visible behind BirthEditor while its
        // dismissal is still animating on iOS 18. A downward app swipe at
        // that moment dismisses Profile itself. Wait for the real transition
        // and tap the exposed card; do not use scrolling as a readiness wait.
        let editorGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.buttons["birth.save"])
        XCTAssertEqual(XCTWaiter.wait(for: [editorGone], timeout: 10), .completed)
        let report = app.buttons["profile.report"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard report.exists && report.isHittable else { return false }
            let frame = report.frame
            return frame.minY >= self.app.navigationBars["我的"].frame.maxY
                && frame.maxY <= self.app.frame.maxY - 34
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        report.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["我的册页"].waitForExistence(timeout: 8))
    }
    private func capture(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func testSystemTabBarOwnsNavigationAndKeepsDraft() {
        launch(); capture("native-tabs-before-interaction")
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "Navigation must use the system tab bar")
        XCTAssertEqual(bar.buttons.count, 3)
        let home = bar.buttons["主页"], calm = bar.buttons["静心"], chat = bar.buttons["问道"]
        XCTAssertTrue(home.exists && calm.exists && chat.exists)
        XCTAssertLessThan(home.frame.midX, calm.frame.midX)
        XCTAssertLessThan(calm.frame.midX, chat.frame.midX)
#if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            let groupGap = calm.frame.minX - home.frame.maxX
            let prominentGap = chat.frame.minX - calm.frame.maxX
            XCTAssertGreaterThan(prominentGap, groupGap + 24, "Chat must be visually separate from the home/calm group")
        }
#endif
        bar.buttons["问道"].tap()
        let input = app.textFields["chat.input"].exists ? app.textFields["chat.input"] : app.textViews["chat.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 8))
        input.tap(); input.typeText("保留原生导航切换前的草稿")
        // Opening and closing Profile dismisses the keyboard without modifying
        // the draft, using the same route as the person using the app.
        tap("nav.profile"); tap("profile.close")
        XCTAssertTrue(bar.buttons["静心"].waitForExistence(timeout: 5))
        bar.buttons["静心"].tap(); bar.buttons["问道"].tap()
        XCTAssertEqual(input.value as? String, "保留原生导航切换前的草稿")
        XCTAssertLessThanOrEqual(input.frame.maxY, bar.frame.minY + 1)
        capture("native-tabs-draft-return")
    }
    func testProfileReportAndProfessionalReturnPreserveChatDraft() {
        launch(); capture("report-01-shell")
        tap("nav.chat")
        let input = app.textFields["chat.input"].exists ? app.textFields["chat.input"] : app.textViews["chat.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 8)); input.tap(); input.typeText("我想了解自己的表达方式")
        tap("nav.profile"); createSyntheticDossier(); capture("report-02-profile")
        openReport()
        XCTAssertTrue(app.staticTexts["report.summary"].waitForExistence(timeout: 25))
        capture("report-03-bazi")
        tap("report.system.ziwei")
        XCTAssertTrue(app.staticTexts["report.summary"].waitForExistence(timeout: 15))
        capture("report-04-ziwei")
        tap("report.professional")
        XCTAssertTrue(app.navigationBars["专业档案"].waitForExistence(timeout: 8))
        capture("report-05-professional")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["我的册页"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["report.system.ziwei"].isSelected, "Returning from the archive retains the selected system")
        capture("report-05b-returned-ziwei")
        tap("report.professional")
        tap("profile.close")
        XCTAssertTrue(input.waitForExistence(timeout: 8))
        XCTAssertEqual(input.value as? String, "我想了解自己的表达方式")
        if app.buttons["chat.dismissKeyboard"].exists { tap("chat.dismissKeyboard") }
        tap("nav.calm"); tap("nav.chat")
        XCTAssertEqual(input.value as? String, "我想了解自己的表达方式")
    }
    func testFourModulesHaveDistinctScopeAndSources() {
        launch(); tap("nav.profile"); createSyntheticDossier(); openReport()
        XCTAssertTrue(app.staticTexts["report.summary"].waitForExistence(timeout: 25))
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'report.entry.'")).firstMatch
        for _ in 0..<8 { if entry.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(entry.isHittable); entry.tap(); capture("report-06-entry")
        let source = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'report.sources.'")).firstMatch
        for _ in 0..<8 { if source.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(source.isHittable); source.tap(); capture("report-07-source")
        let rawPointer = app.staticTexts["/mingPan/riZhu"]
        XCTAssertFalse(rawPointer.exists, "Technical fields stay behind the second disclosure")
        let fields = app.buttons["report.fields.module.day-month"]
        for _ in 0..<8 { if fields.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(fields.isHittable); fields.tap()
        XCTAssertTrue(rawPointer.waitForExistence(timeout: 5))
        capture("report-07b-raw-fields")
        fields.tap()
        XCTAssertFalse(rawPointer.exists)
        for _ in 0..<10 { if app.buttons["report.system.mansions"].isHittable { break }; app.swipeDown() }
        tap("report.system.mansions")
        XCTAssertTrue(app.staticTexts["report.summary"].waitForExistence(timeout: 30)); capture("report-08-mansions")
        tap("report.system.qizheng")
        XCTAssertTrue(app.staticTexts["report.summary"].waitForExistence(timeout: 20)); capture("report-09-qizheng")
        tap("report.professional"); tap("professional.astronomy")
        XCTAssertTrue(app.staticTexts["出生时的天空"].waitForExistence(timeout: 20)); capture("report-10-astronomy")
    }
    func testDarkReportNavigationRemainsReachable() {
        app.launchArguments += ["--test-dark"]
        launch(); capture("report-11-standard-shell"); tap("nav.profile"); createSyntheticDossier(); openReport()
        let summary = app.staticTexts["report.summary"]
        for _ in 0..<10 { if summary.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(summary.waitForExistence(timeout: 25)); capture("report-12-standard-bazi")
        for _ in 0..<10 { if app.buttons["report.system.ziwei"].isHittable { break }; app.swipeDown() }
        tap("report.system.ziwei"); capture("report-13-standard-ziwei")
        tap("report.professional"); tap("profile.close")
        XCTAssertTrue(app.buttons["ritual.reveal"].waitForExistence(timeout: 10))
    }
    func testModuleReadingShowsConditionsBeforeProfessionalFields() {
        launch(); tap("nav.profile"); createSyntheticDossier(); openReport()
        XCTAssertTrue(app.staticTexts["report.summary"].waitForExistence(timeout: 25))
        XCTAssertFalse(app.buttons["theme.continue"].exists, "The paused life-theme experiment is not the default report")
        tap("report.entry.module.pattern")
        XCTAssertEqual(app.buttons["report.entry.module.pattern"].value as? String, "已展开")
        XCTAssertFalse(app.staticTexts["/mingPan/geJuV2"].exists, "The ordinary reading is not raw engine output")
        capture("report-14-pattern-conditions")
        tap("report.entry.module.methods")
        XCTAssertEqual(app.buttons["report.entry.module.methods"].value as? String, "已展开")
        capture("report-15-methods-scope")
        tap("report.entry.module.methods")
        XCTAssertEqual(app.buttons["report.entry.module.methods"].value as? String, "已收起")
        tap("report.entry.module.pattern")
        XCTAssertEqual(app.buttons["report.entry.module.pattern"].value as? String, "已收起")
        tap("report.professional")
        XCTAssertTrue(app.navigationBars["专业档案"].waitForExistence(timeout: 8), "Expansion and collapse must leave scrolling and navigation responsive")
    }
}
