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
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 15), id)
        for _ in 0..<9 { if button.isHittable { break }; app.swipeUp() }
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
        let report = app.buttons["profile.report"]
        XCTAssertTrue(report.waitForExistence(timeout: 10))
        let title = report.staticTexts["我的册页"]
        // After dismissing BirthEditor at AX XXXL, the card is partly above
        // the navigation bar. A hittable card does not guarantee its center
        // is exposed. Scroll its actual title into view before tapping it.
        let contentTop = app.navigationBars["我的"].frame.maxY + 8
        for _ in 0..<8 {
            if title.isHittable && title.frame.minY >= contentTop { break }
            app.swipeDown()
        }
        XCTAssertTrue(title.isHittable && title.frame.minY >= contentTop)
        title.tap()
        XCTAssertTrue(app.navigationBars["我的册页"].waitForExistence(timeout: 8))
    }
    private func capture(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
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
        let rawPointer = app.staticTexts["/mingPan/riZhu/gan"]
        XCTAssertFalse(rawPointer.exists, "Technical fields stay behind the second disclosure")
        let fields = app.buttons["report.fields.day.reference"]
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
    func testLargeDarkReportNavigationRemainsReachable() {
        app.launchArguments += ["--test-dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launch(); capture("report-11-large-shell"); tap("nav.profile"); createSyntheticDossier(); openReport()
        let summary = app.staticTexts["report.summary"]
        for _ in 0..<10 { if summary.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(summary.waitForExistence(timeout: 25)); capture("report-12-large-bazi")
        for _ in 0..<10 { if app.buttons["report.system.ziwei"].isHittable { break }; app.swipeDown() }
        tap("report.system.ziwei"); capture("report-13-large-ziwei")
        tap("report.professional"); tap("profile.close")
        XCTAssertTrue(app.buttons["ritual.reveal"].waitForExistence(timeout: 10))
    }
}
