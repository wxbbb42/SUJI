import XCTest

/// Production views, synthetic records. No account restoration or AI requests.
final class MingliDetailsUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--mingli-detail-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
    }

    private func capture(_ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-accessibility-tree"; tree.lifetime = .keepAlways; add(tree)
    }

    private func launchFixture(_ link: String) {
        app.launch()
        XCTAssertTrue(app.staticTexts["audit.synthetic"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons[link].waitForExistence(timeout: 10)); app.buttons[link].tap()
    }

    private var contentTop: CGFloat {
        max(app.navigationBars.firstMatch.frame.maxY, app.staticTexts["audit.synthetic"].frame.maxY) + 3
    }

    @discardableResult private func reveal(_ id: String, type: XCUIElement.ElementType = .any) -> XCUIElement {
        let target = app.descendants(matching: type).matching(identifier: id).firstMatch
        for _ in 0..<14 {
            if target.exists && target.isHittable && target.frame.minY > contentTop { return target }
            app.swipeUp()
        }
        XCTFail("Unreachable accessible element: \(id)")
        return target
    }

    private func showEntireRow(_ target: XCUIElement) {
        for _ in 0..<4 {
            let input = app.textFields["reflection.input"]
            let contentBottom = input.exists ? input.frame.minY - 30 : app.frame.maxY - 40
            let overflow = target.frame.maxY - contentBottom
            let movable = target.frame.minY - contentTop - 12
            guard overflow > 0, movable > 0 else { return }
            let distance = min(overflow + 12, movable, app.frame.height * 0.3)
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)))
        }
    }

    private func inspectEvidence(large: Bool) {
        launchFixture("六爻明细验收")
        capture(large ? "40-liuyao-xxxl-overview" : "30-liuyao-overview")
        reveal("六爻明细 · 上爻至初爻", type: .button).tap()
        let upper = reveal("evidence.liuyao.line.6")
        XCTAssertTrue(upper.label.contains("第6爻")); XCTAssertTrue(upper.label.contains("少阳"))
        showEntireRow(upper)
        capture(large ? "41-liuyao-xxxl-upper" : "31-liuyao-upper")
        let lower = reveal("evidence.liuyao.line.1")
        XCTAssertTrue(lower.label.contains("第1爻")); XCTAssertTrue(lower.label.contains("老阴"))
        XCTAssertTrue(lower.label.contains("变爻"))
        showEntireRow(lower)
        capture(large ? "42-liuyao-xxxl-lower" : "32-liuyao-lower")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["奇门明细验收"].tap()
        capture(large ? "43-qimen-xxxl-overview" : "33-qimen-overview")
        reveal("九宫明细", type: .button).tap()
        let first = reveal("evidence.qimen.palace.1")
        XCTAssertTrue(first.label.contains("地盘")); XCTAssertTrue(first.label.contains("天盘"))
        showEntireRow(first)
        capture(large ? "44-qimen-xxxl-first" : "34-qimen-first")
        let middle = reveal("evidence.qimen.palace.5")
        XCTAssertTrue(middle.label.contains("天禽")); XCTAssertTrue(middle.label.contains("中宫不布八门与八神"))
        showEntireRow(middle)
        capture(large ? "45-qimen-xxxl-center" : "35-qimen-center")
        let last = reveal("evidence.qimen.palace.9")
        XCTAssertTrue(last.label.contains("9宫"))
        showEntireRow(last)
        capture(large ? "46-qimen-xxxl-last" : "36-qimen-last")
    }

    func testEvidenceDetails() { inspectEvidence(large: false) }
    func testEvidenceDetailsAtXXXL() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        inspectEvidence(large: true)
    }

    private func inspectArchives(large: Bool) {
        launchFixture("历史整理分组验收")
        XCTAssertTrue(app.buttons["重试这次整理"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["重试这次整理"].isEnabled)
        reveal("较早的整理（只读）", type: .button).tap()
        let groupForFraming = app.buttons[large ? "reflection.archive.ui-audit:previous-birth" : "reflection.archive.ui-audit:imported"]
        showEntireRow(groupForFraming)
        capture(large ? "51-archives-xxxl-groups" : "37-archives-groups")
        let ids = ["ui-audit:previous-birth", "ui-audit:previous-engine", "ui-audit:imported"]
        let labels = ["旧出生资料", "旧计算版本", "导入旧记录"]
        let replies = ["旧出生资料的占位段落，非模型回信", "旧计算版本的占位段落，非模型回信", "导入记录的占位段落，非模型回信"]
        for (index, id) in ids.enumerated() {
            let group = reveal("reflection.archive." + id, type: .button)
            XCTAssertTrue(group.label.contains(labels[index]))
            group.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.02)).tap()
            let reply = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", replies[index])).firstMatch
            for _ in 0..<7 { if reply.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(reply.isHittable)
            showEntireRow(reply)
            capture("\(large ? 52 + index : 38 + index)-archive-\(large ? "xxxl-" : "")\(index)")
            for _ in 0..<8 {
                if group.isHittable && group.frame.minY > contentTop { break }
                app.swipeDown()
            }
            group.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.02)).tap()
            XCTAssertFalse(reply.exists, "Collapsed history must not remain in the accessibility tree")
        }
        XCTAssertTrue(app.textFields["reflection.input"].exists || app.textViews["reflection.input"].exists)
    }
    func testReflectionArchiveGroups() { inspectArchives(large: false) }
    func testReflectionArchiveGroupsAtXXXL() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        inspectArchives(large: true)
    }

    func testChatPlaceholderLightAndDark() {
        app.launchArguments.removeAll { $0 == "--mingli-detail-fixtures" }
        app.launchArguments += ["--notebook-fixtures"]
        for dark in [false, true] {
            if dark { app.launchArguments += ["--test-dark"] }
            app.launch()
            XCTAssertTrue(app.tabBars.buttons["问道"].waitForExistence(timeout: 20))
            app.tabBars.buttons["问道"].tap()
            let input = app.textFields["chat.input"]
            XCTAssertTrue(input.waitForExistence(timeout: 5)); XCTAssertEqual(input.label, "写下此刻的心事")
            capture(dark ? "61-chat-placeholder-dark" : "60-chat-placeholder-light")
            let bounds = XCTAttachment(string: "screen=\(app.frame); input=\(input.frame)")
            bounds.name = dark ? "61-placeholder-bounds" : "60-placeholder-bounds"; bounds.lifetime = .keepAlways; add(bounds)
            app.terminate()
        }
    }
}
