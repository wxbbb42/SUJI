import XCTest

extension XCUIApplication {
    func notebookNavigationButton(_ identifier: String) -> XCUIElement {
        // A SwiftUI tabItem label's identifier is not consistently forwarded
        // by UITabBar. Query the actual native control by role and title.
        let titles = ["nav.today": "主页", "nav.chat": "问道", "nav.calm": "静心"]
        if let title = titles[identifier] { return tabBars.firstMatch.buttons[title] }
        return buttons[identifier]
    }
    /// Navigate the shipped shell, dismissing the personal container when moving
    /// between main pages. No synthetic routes or production data are injected.
    func selectNotebookPage(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        if buttons["profile.close"].exists { buttons["profile.close"].tap() }
        let ids = ["我的": "nav.profile", "主页": "nav.today", "今日": "nav.today", "问道": "nav.chat", "静心": "nav.calm"]
        let button = notebookNavigationButton(ids[title] ?? title)
        XCTAssertTrue(button.waitForExistence(timeout: 10), title, file: file, line: line)
        button.tap()
    }
    func openProfessionalCharts(file: StaticString = #filePath, line: UInt = #line) {
        selectNotebookPage("我的", file: file, line: line)
        XCTAssertTrue(buttons["profile.report"].waitForExistence(timeout: 25), file: file, line: line)
        buttons["profile.report"].tap()
        XCTAssertTrue(buttons["report.professional"].waitForExistence(timeout: 10), file: file, line: line)
        buttons["report.professional"].tap()
        XCTAssertTrue(buttons["professional.charts"].waitForExistence(timeout: 10), file: file, line: line)
        buttons["professional.charts"].tap()
    }
    func openNotebookSettings(file: StaticString = #filePath, line: UInt = #line) {
        selectNotebookPage("我的", file: file, line: line)
        let settings = buttons["profile.settings"]
        for _ in 0..<8 { if settings.isHittable { break }; swipeUp() }
        XCTAssertTrue(settings.isHittable, file: file, line: line)
        settings.tap()
    }
}
