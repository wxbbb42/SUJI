import XCTest

final class NatalAstronomyUITests: XCTestCase {
    func testBirthAstronomyAndModernMansionAreReadable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--notebook-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["nav.profile"].waitForExistence(timeout: 15))
        app.selectNotebookPage("我的")
        app.buttons["profile.addBirth"].tap()
        let confirm = app.switches["birth.confirm"]
        for _ in 0..<8 { if confirm.isHittable { break }; app.swipeUp() }
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["birth.save"].tap()
        XCTAssertTrue(app.staticTexts["profile.dossierReady"].waitForExistence(timeout: 25))
        app.buttons["profile.report"].tap()
        app.buttons["report.professional"].tap()
        let entry = app.buttons["professional.astronomy"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        for _ in 0..<8 { if entry.isHittable { break }; app.swipeUp() }
        entry.tap()
        XCTAssertTrue(app.staticTexts["出生时的天空"].waitForExistence(timeout: 15))
        capture(app, "astronomy-seven-bodies")
        let mansion = app.otherElements["astronomy.moonMansion"]
        let uncertainty = app.staticTexts["出生时间精度未知，宿界归属保留不确定性；小数位数不代表实际准确度。"]
        for _ in 0..<12 { if uncertainty.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(uncertainty.isHittable)
        XCTAssertTrue(mansion.exists || app.staticTexts["现代星名距星参照"].exists)
        capture(app, "astronomy-modern-mansion")
        let residual = app.staticTexts["四余 · 平轨道法"]
        for _ in 0..<8 { if residual.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(residual.isHittable)
        capture(app, "astronomy-four-residuals")
        let houses = app.buttons["十二宫排布"]
        for _ in 0..<8 { if houses.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(houses.isHittable)
        houses.tap()
        capture(app, "astronomy-life-degree")
        let sources = app.buttons["计算口径与来源"]
        for _ in 0..<10 { if sources.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(sources.isHittable)
        sources.tap()
        app.swipeUp()
        capture(app, "astronomy-method-and-limits")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
