import XCTest

/// Real local engine, immutable recorded trace and production SwiftUI components.
/// Synthetic birth data only; no account or model connection.
final class StrengthTracePresentationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reading-presentation-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
    }

    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-accessibility-tree"; tree.lifetime = .keepAlways; add(tree)
    }

    private var contentTop: CGFloat {
        max(app.navigationBars.firstMatch.frame.maxY, app.staticTexts["audit.synthetic"].exists ? app.staticTexts["audit.synthetic"].frame.maxY : 0) + 6
    }

    private var contentBottom: CGFloat {
        let composer = app.otherElements["chat.composer"]
        return composer.exists ? composer.frame.minY - 8 : app.frame.maxY - 40
    }

    private func reveal(_ target: XCUIElement, alignToTop: Bool = false) {
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        for _ in 0..<40 {
            let top = contentTop, bottom = contentBottom
            if target.isHittable && target.frame.minY >= top && target.frame.minY < bottom - 32
                && (!alignToTop || target.frame.minY <= top + 24) { return }
            let delta = target.frame.minY - top - 12
            let limit = max(40, (bottom - top) * 0.65)
            let start = delta > 0 ? bottom - 20 : top + 20
            let end = start - max(-limit, min(limit, delta))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.midX, dy: start)).press(forDuration: 0.1,
                thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: end)),
                withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(target.isHittable)
        XCTAssertGreaterThanOrEqual(target.frame.minY, contentTop)
    }

    private func inspectTrace(_ identifier: String, capturePrefix: String) {
        let toggle = app.staticTexts[identifier + ".toggle"]
        reveal(toggle)
        XCTAssertGreaterThanOrEqual(toggle.frame.height, 44)
        let groups = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", identifier + ".group."))
        XCTAssertEqual(groups.count, 0, "Details should initially be collapsed")
        let qualification = app.staticTexts[identifier == "reading.strength.trace" ? "reading.body.strength" : identifier + ".qualification"]
        XCTAssertTrue(qualification.exists)
        XCTAssertTrue(qualification.label.contains("不是实测力量"))
        capture(capturePrefix + "-collapsed")
        toggle.tap()
        capture(capturePrefix + "-opened")
        XCTAssertTrue(groups.firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(groups.count, 2)
        XCTAssertTrue(app.staticTexts[identifier + ".row.threshold"].label.contains("4 ≥ 4"))
        XCTAssertTrue(app.staticTexts[identifier + ".row.day-master"].label.contains("计 1"))
        reveal(groups.element(boundBy: 0))
        capture(capturePrefix + "-first-group")
        reveal(app.staticTexts[identifier + ".row.threshold"])
        capture(capturePrefix + "-boundary")
        let last = groups.element(boundBy: groups.count - 1)
        reveal(last)
        XCTAssertGreaterThanOrEqual(last.frame.minX, 0)
        XCTAssertLessThanOrEqual(last.frame.maxX, app.frame.maxX)
        capture(capturePrefix + "-last-group")
        reveal(toggle); toggle.tap()
        XCTAssertEqual(groups.count, 0)
        XCTAssertTrue(qualification.exists, "The qualification must remain when details collapse")
    }

    private func inspectChat(_ prefix: String) {
        app.launch()
        XCTAssertTrue(app.textFields["chat.input"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["audit.synthetic"].exists)
        let qualification = app.staticTexts["reading.qualification.strength"]
        XCTAssertTrue(qualification.label.contains("启发式"))
        inspectTrace("reading.strength.trace", capturePrefix: prefix + "-chat")
        let evidence = app.buttons["reading.evidence.top"]
        reveal(evidence); evidence.tap()
        XCTAssertTrue(app.navigationBars["计算依据"].waitForExistence(timeout: 5))
        let summary = app.staticTexts["evidence.strength.trace.ui-audit:bazi-framework.summary"]
        XCTAssertTrue(summary.exists)
        XCTAssertTrue(summary.label.contains("帮扶 4，克泄耗 4"))
        reveal(summary)
        capture(prefix + "-evidence-entry")
        inspectTrace("evidence.strength.trace.ui-audit:bazi-framework", capturePrefix: prefix + "-evidence")
    }

    func testStrengthTraceLight() { inspectChat("10-light") }
    func testStrengthTraceDark() {
        app.launchArguments += ["--test-dark"]
        inspectChat("20-dark")
    }

    func testBriefStrengthKeepsQualificationsWithoutRepeatingLongFootnote() {
        app.launchArguments += ["--strength-brief-fixture"]
        app.launch()
        let body = app.staticTexts["reading.body.strength-brief"]
        reveal(app.staticTexts["reading.title.strength-brief"], alignToTop: true)
        let qualification = app.staticTexts["reading.qualification.strength-brief"]
        XCTAssertTrue(qualification.label.contains("启发式"))
        XCTAssertLessThan(body.label.count, 100)
        XCTAssertTrue(body.label.contains("含日干一次"))
        XCTAssertTrue(body.label.contains("未综合月令、根气与调候"))
        XCTAssertTrue(body.label.contains("不能当作完整强弱结论"))
        capture("60-brief-chat-collapsed")
        XCTAssertFalse(app.staticTexts["reading.strength.trace.qualification"].exists,
                       "The brief answer already states the limits; do not append the long footnote again")
        let toggle = app.staticTexts["reading.strength.trace.toggle"]
        reveal(toggle)
        XCTAssertGreaterThanOrEqual(toggle.frame.height, 44)
        toggle.tap()
        XCTAssertTrue(app.staticTexts["reading.strength.trace.group.count"].waitForExistence(timeout: 5))
        XCTAssertTrue(qualification.exists)
        capture("61-brief-chat-opened")
        reveal(toggle); toggle.tap()
        XCTAssertTrue(qualification.exists)
        XCTAssertFalse(app.staticTexts["reading.strength.trace.group.count"].exists)
    }

    func testStructureHeadingAndEvidenceMetadata() {
        app.launch()
        let toggle = app.staticTexts["reading.strength.trace.toggle"]
        reveal(toggle); toggle.tap()
        let heading = app.staticTexts["reading.strength.trace.group.structure"]
        reveal(heading, alignToTop: true)
        XCTAssertLessThanOrEqual(heading.frame.maxY, contentBottom)
        capture("70-standard-structure-heading")
        reveal(toggle); toggle.tap()
        let evidence = app.buttons["reading.evidence.top"]
        reveal(evidence); evidence.tap()
        XCTAssertTrue(app.navigationBars["计算依据"].waitForExistence(timeout: 5))
        app.swipeUp()
        let metadata = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "提问时刻,")).firstMatch
        reveal(metadata, alignToTop: true)
        capture("71-standard-evidence-metadata")
        XCTAssertTrue(metadata.isHittable)
        XCTAssertTrue(metadata.label.contains("2026年9月19日"))
    }

    private func inspectProfile(_ prefix: String) {
        app.launchArguments += ["--strength-profile-fixture"]
        app.launch()
        XCTAssertTrue(app.navigationBars["命盘手稿"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["audit.synthetic"].exists)
        for label in ["计数较多", "计数较少"] {
            let value = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
            for _ in 0..<12 {
                if value.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(value.isHittable)
        }
        capture(prefix + "-profile-count-labels")
        let summary = app.staticTexts["profile.strength.trace.summary"]
        reveal(summary)
        XCTAssertTrue(summary.label.contains("帮扶 4，克泄耗 4"))
        capture(prefix + "-profile-summary")
        inspectTrace("profile.strength.trace", capturePrefix: prefix + "-profile")
    }
    func testStrengthTraceProfile() { inspectProfile("40-light") }
}
