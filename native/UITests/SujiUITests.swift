import XCTest

final class SujiUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--notebook-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
    }
    private func begin() {
        app.launch()
        XCTAssertTrue(app.buttons["ritual.reveal"].waitForExistence(timeout: 10))
    }
    func testAccountGateBlocksNotebookBeforeLogin() {
        app.launchArguments.removeAll { $0 == "--notebook-fixtures" }
        app.launch()
        XCTAssertTrue(app.navigationBars["欢迎来到有时"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.textFields["邮箱地址"].exists)
        XCTAssertFalse(app.tabBars.buttons["今日"].exists)
        XCTAssertFalse(app.buttons["ritual.reveal"].exists)
        capture("01-account-required")
        app.buttons["注册"].tap()
        XCTAssertTrue(app.buttons["创建账户"].exists)
        app.buttons["重置"].tap()
        XCTAssertTrue(app.buttons["发送重置邮件"].exists)
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testRitualJournalHistoryAndShare() {
        begin(); capture("02-today-paper")
        app.buttons["ritual.reveal"].tap()
        XCTAssertTrue(app.buttons["ritual.journal"].waitForExistence(timeout: 5))
        capture("03-today-revealed")
        app.buttons["ritual.journal"].tap()
        let note = app.textFields["journal.note"]
        XCTAssertTrue(note.waitForExistence(timeout: 5)); note.tap(); note.typeText("今天慢慢走了一段路。")
        app.buttons["journal.save"].tap()
        app.buttons["ritual.history"].tap()
        XCTAssertTrue(app.navigationBars["七日回望"].waitForExistence(timeout: 5)); capture("04-history")
        app.buttons["完成"].tap()
        app.buttons["ritual.share"].tap()
        XCTAssertTrue(app.buttons["分享这一刻"].waitForExistence(timeout: 10)); capture("05-share-preview")
        app.buttons["完成"].tap()
        app.tabBars.buttons["我的"].tap()
        app.buttons.containing(.staticText, identifier: "心情册页").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["今天慢慢走了一段路。"].waitForExistence(timeout: 5)); capture("06-journal")
    }
    func testPaperDragReturnsThenReveals() {
        begin()
        let paper = app.otherElements["ritual.paper"].firstMatch
        XCTAssertTrue(paper.waitForExistence(timeout: 5))
        let corner = paper.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.94))
        corner.press(forDuration: 0.1, thenDragTo: paper.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.87)), withVelocity: .slow, thenHoldForDuration: 0.2)
        XCTAssertTrue(app.buttons["ritual.reveal"].exists)
        XCTAssertFalse(app.buttons["ritual.journal"].exists)
        capture("21-paper-returned")
        corner.press(forDuration: 0.1, thenDragTo: paper.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.2)), withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(app.buttons["ritual.journal"].waitForExistence(timeout: 8))
        capture("22-paper-drag-revealed")
    }
    func testBreathingAndBirthProfile() {
        begin(); app.tabBars.buttons["静心"].tap(); capture("07-calm")
        app.buttons["开始"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 5)); capture("08-breathing")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "音景播放中").firstMatch.waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "音景播放中").firstMatch.waitForExistence(timeout: 5))
        app.buttons["暂停"].tap()
        XCTAssertTrue(app.buttons["继续"].exists)
        app.buttons["结束静心"].tap()
        XCTAssertTrue(app.buttons["开始"].exists)
        app.tabBars.buttons["我的"].tap(); capture("09-profile-empty")
        app.buttons["profile.addBirth"].tap()
        XCTAssertTrue(app.buttons["birth.save"].waitForExistence(timeout: 5)); capture("10-birth-editor")
        app.switches["birth.confirm"].tap()
        app.buttons["birth.save"].tap()
        XCTAssertTrue(app.staticTexts["你的底色"].waitForExistence(timeout: 20)); capture("11-profile")
        app.swipeUp()
        app.buttons.containing(.staticText, identifier: "命盘手稿").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["命盘手稿"].waitForExistence(timeout: 5)); capture("12-four-pillars")
        app.buttons["紫微"].tap(); capture("13-ziwei")
    }
    func testManagedAIRequiresLoginAndSettingsHaveNoProviderFields() {
        begin(); app.tabBars.buttons["问道"].tap(); capture("14-chat-empty")
        let input = app.textFields["chat.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("今天想慢一点。")
        app.buttons["发送"].tap()
        XCTAssertTrue(app.buttons["账户与登录"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "请先登录账户")).firstMatch.exists)
        capture("15-ai-login-needed")
        app.buttons["账户与登录"].tap()
        XCTAssertTrue(app.navigationBars["账户与云端资料"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["通过 Google 继续"].exists)
        app.tabBars.buttons["我的"].tap()
        if !app.navigationBars["设置"].exists { app.buttons["设置"].tap() }
        XCTAssertTrue(app.staticTexts["回信伙伴, DeepSeek Flash"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["服务地址"].exists)
        XCTAssertFalse(app.textFields["模型名称"].exists)
        XCTAssertFalse(app.secureTextFields["API Key"].exists)
        capture("16-settings")
        app.swipeUp(); app.buttons["晨间与节气提醒"].tap()
        capture("17-reminders")
    }
    func testDarkAndAccessibleRitual() {
        app.launchArguments += ["--test-dark"]
        begin(); capture("26-dark-paper")
        app.terminate()
        app.launchArguments += ["--test-dark", "--test-reduce-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        begin(); capture("18-dark-large-paper")
        app.buttons["ritual.reveal"].tap()
        XCTAssertTrue(app.buttons["ritual.journal"].waitForExistence(timeout: 5)); capture("19-dark-large-revealed")
        app.tabBars.buttons["静心"].tap(); capture("20-dark-large-calm")
        for _ in 0..<4 { if app.buttons["开始"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.buttons["开始"].isHittable)
        app.buttons["开始"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 5)); capture("23-dark-large-controls")
        app.tabBars.buttons["问道"].tap(); capture("27-dark-large-chat")
        XCTAssertTrue(app.textFields["chat.input"].isHittable)
        app.tabBars.buttons["我的"].tap(); capture("28-dark-large-profile")
        for _ in 0..<4 { if app.buttons["profile.addBirth"].isHittable { break }; app.swipeUp() }
        app.buttons["profile.addBirth"].tap()
        XCTAssertTrue(app.buttons["birth.save"].waitForExistence(timeout: 5))
        app.switches["birth.confirm"].tap()
        app.buttons["birth.save"].tap()
        XCTAssertTrue(app.staticTexts["你的底色"].waitForExistence(timeout: 20))
        app.swipeUp(); capture("29-dark-large-profile-reading")
    }
    func testCeladonTheme() {
        begin(); app.tabBars.buttons["我的"].tap()
        app.buttons["设置"].tap()
        app.buttons["appearance.picker"].tap()
        app.buttons["青瓷"].tap()
        app.tabBars.buttons["今日"].tap(); capture("24-celadon-today")
        app.tabBars.buttons["静心"].tap(); capture("25-celadon-calm")
    }
}
