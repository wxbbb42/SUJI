import XCTest

/// Synthetic birth inputs, real local calculation and presentation; no network.
final class ReadingPresentationUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reading-presentation-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
    }

    private func capture(_ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-accessibility-tree"; tree.lifetime = .keepAlways; add(tree)
    }

    private var contentTop: CGFloat { max(app.navigationBars.firstMatch.frame.maxY, app.staticTexts["audit.synthetic"].frame.maxY) + 6 }
    private var contentBottom: CGFloat { app.otherElements["chat.composer"].frame.minY - 8 }

    /// Position a heading in the actual area between navigation/banner and composer.
    /// Long bodies may exceed that area; they stay scrollable rather than truncated.
    private func reveal(_ target: XCUIElement, followingHeight: CGFloat = 0, allowOverflow: Bool = false) {
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        for _ in 0..<30 {
            let top = contentTop, bottom = contentBottom
            let delta = target.frame.minY - top - 12
            if target.isHittable && target.frame.minY >= top && (allowOverflow || target.frame.maxY + followingHeight <= bottom) { return }
            let limit = max(40, (bottom - top) * 0.7)
            let startY = delta > 0 ? bottom - 20 : top + 20
            let endY = startY - max(-limit, min(limit, delta))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.midX, dy: startY)).press(forDuration: 0.1,
                thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: endY)),
                withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        XCTAssertTrue(target.isHittable)
        XCTAssertGreaterThanOrEqual(target.frame.minY, contentTop)
    }

    private func launch() {
        app.launch()
        XCTAssertTrue(app.textFields["chat.input"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["audit.synthetic"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["命理"].isSelected, "Follow-up mode should match the retained user turn")
    }

    private func inspectQualifiedReading(_ prefix: String) {
        launch()
        let evidence = app.buttons["reading.evidence.top"]
        reveal(evidence)
        XCTAssertGreaterThanOrEqual(evidence.frame.height, 44)
        capture(prefix + "-entry")
        evidence.tap()
        XCTAssertTrue(app.navigationBars["计算依据"].waitForExistence(timeout: 5))
        capture(prefix + "-evidence")
        let referenceTime = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "提问时刻,")).firstMatch
        // The strength summary now precedes metadata; List virtualizes rows
        // below the large-text viewport, so verify their reachable position.
        for _ in 0..<12 {
            if referenceTime.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(referenceTime.isHittable)
        XCTAssertTrue(referenceTime.label.contains("2026年9月19日"))
        capture(prefix + "-metadata")
        app.navigationBars.buttons.firstMatch.tap()
        let checks = [
            ("strength", "启发式参考", "不是实测力量"),
            ("pattern", "结构候选", "不能据此说已经成格"),
            ("tiaohou", "文献候选", "尚未完成印刷底本校勘"),
        ]
        for (id, label, requiredBody) in checks {
            let heading = app.staticTexts["reading.title." + id]
            let qualification = app.staticTexts["reading.qualification." + id]
            reveal(heading, followingHeight: qualification.frame.height + 12)
            XCTAssertTrue(qualification.isHittable)
            XCTAssertTrue(qualification.label.contains(label))
            XCTAssertLessThanOrEqual(qualification.frame.maxX, app.frame.maxX)
            XCTAssertGreaterThanOrEqual(qualification.frame.minX, 0)
            XCTAssertTrue(app.staticTexts["reading.body." + id].label.contains(requiredBody))
            capture(prefix + "-" + id)
        }
        let bottom = app.buttons["reading.evidence.bottom"]
        reveal(bottom)
        XCTAssertGreaterThanOrEqual(bottom.frame.height, 44)
        XCTAssertTrue(app.textFields["chat.input"].isHittable)
        let copy = app.buttons["reading.copy"]
        reveal(copy); copy.tap()
        XCTAssertTrue(copy.label.contains("已复制完整回信"))
        capture(prefix + "-end")
    }

    func testQualifiedReadingLight() { inspectQualifiedReading("10-light") }
    func testQualifiedReadingDark() {
        app.launchArguments += ["--test-dark"]
        inspectQualifiedReading("20-dark")
    }
    func testQualifiedReadingAtXXXL() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        inspectQualifiedReading("30-xxxl")
    }

    func testFocusedFollowupKeepsQualifications() {
        app.launchArguments += ["--reading-followup-fixture"]
        launch()
        let heading = app.staticTexts["reading.title.overview"]
        reveal(heading)
        let body = app.staticTexts["reading.body.overview"]
        XCTAssertTrue(body.label.contains("启发式"))
        XCTAssertTrue(body.label.contains("候选"))
        capture("40-followup-overview")
        let input = app.textFields["chat.input"]
        XCTAssertTrue(input.isHittable)
        input.tap(); input.typeText("Why?")
        XCTAssertTrue(app.buttons["发送"].isEnabled)
        XCTAssertTrue(app.segmentedControls.buttons["命理"].isSelected)
        capture("41-followup-composer")
    }

    func testFailedCalculationRecoveryAtXXXL() {
        app.launchArguments += ["--reading-failure-fixture", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launch()
        let failure = app.staticTexts["chat.failure"]
        reveal(failure, allowOverflow: true)
        XCTAssertTrue(failure.label.contains("出生资料已保留"))
        XCTAssertFalse(app.buttons["reading.evidence.top"].exists)
        XCTAssertFalse(app.buttons["reading.evidence.bottom"].exists)
        capture("50-failure-xxxl")
        let retry = app.buttons["chat.retry"]
        reveal(retry)
        XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
        XCTAssertTrue(retry.isEnabled)
        capture("51-failure-actions-xxxl")
        app.buttons["chat.account"].tap()
        XCTAssertTrue(app.navigationBars["账户与云端资料"].waitForExistence(timeout: 5))
        capture("52-failure-account-xxxl")
    }

    func testCompletedDocumentStartsAtBeginning() {
        app.launchArguments += ["--reading-delivery-fixture"]
        launch()
        let heading = app.staticTexts["reading.title.chart"]
        XCTAssertTrue(heading.waitForExistence(timeout: 10))
        XCTAssertTrue(heading.isHittable)
        XCTAssertGreaterThanOrEqual(heading.frame.minY, contentTop)
        XCTAssertLessThan(heading.frame.maxY, contentBottom)
        XCTAssertFalse(app.buttons["reading.evidence.bottom"].isHittable,
                       "Draft cleanup must not jump to the end of the completed reply")
        XCTAssertTrue(app.textFields["chat.input"].isHittable)
        capture("60-completed-reply-start")
    }
}
