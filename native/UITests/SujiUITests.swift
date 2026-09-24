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
        XCTAssertFalse(app.buttons["nav.today"].exists)
        XCTAssertFalse(app.buttons["ritual.reveal"].exists)
        capture("01-account-required")
        app.buttons["注册"].tap()
        XCTAssertTrue(app.buttons["创建账户"].exists)
        app.buttons["重置"].tap()
        XCTAssertTrue(app.buttons["发送重置邮件"].exists)
    }
    func testBirthFormRequiresConfirmationAndBuildsDossier() {
        begin()
        app.selectNotebookPage("我的")
        app.buttons["profile.addBirth"].tap()
        let save = app.buttons["birth.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        let confirm = app.switches["birth.confirm"]
        for _ in 0..<8 { if confirm.isHittable { break }; app.swipeUp() }
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(save.isEnabled)
        capture("02-birth-confirmed")
        save.tap()
        XCTAssertTrue(app.staticTexts["profile.dossierReady"].waitForExistence(timeout: 25))
        capture("03-natal-dossier-ready")
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
        for _ in 0..<8 { if app.buttons["ritual.history"].isHittable { break }; app.swipeUp() }
        app.buttons["ritual.history"].tap()
        XCTAssertTrue(app.navigationBars["七日回望"].waitForExistence(timeout: 5)); capture("04-history")
        app.buttons["完成"].tap()
        for _ in 0..<8 { if app.buttons["ritual.share"].isHittable { break }; app.swipeDown() }
        app.buttons["ritual.share"].tap()
        XCTAssertTrue(app.buttons["分享这一刻"].waitForExistence(timeout: 10)); capture("05-share-preview")
        app.buttons["完成"].tap()
        app.selectNotebookPage("我的")
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
    func testPaperCornerTapAndReachableDrag() {
        begin()
        let paper = app.otherElements["ritual.paper"].firstMatch
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.94)).tap()
        XCTAssertTrue(app.buttons["ritual.journal"].waitForExistence(timeout: 5))
        app.terminate()
        begin()
        let corner = paper.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.94))
        let reachable = corner.withOffset(CGVector(dx: -80, dy: -88))
        corner.press(forDuration: 0.1, thenDragTo: reachable, withVelocity: .slow, thenHoldForDuration: 0.2)
        XCTAssertTrue(app.buttons["ritual.journal"].waitForExistence(timeout: 5))
        capture("30-reachable-drag-revealed")
    }

    func testPaperVerticalAndShortPullStayUnrevealed() {
        begin()
        XCTAssertTrue(app.staticTexts["ritual.season"].waitForExistence(timeout: 5))
        capture("31-standard-paper-top")
        let reveal = app.buttons["ritual.reveal"]
        for _ in 0..<8 { if reveal.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(reveal.isHittable)
        let handle = app.buttons["ritual.corner"]
        XCTAssertTrue(handle.isHittable)
        var corner = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.65))
        corner.press(forDuration: 0.1, thenDragTo: corner.withOffset(CGVector(dx: 0, dy: -55)), withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(reveal.exists)
        XCTAssertFalse(app.buttons["ritual.journal"].exists)
        for _ in 0..<5 { if reveal.isHittable { break }; app.swipeUp() }
        corner = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.65))
        corner.press(forDuration: 0.1, thenDragTo: corner.withOffset(CGVector(dx: -18, dy: -20)), withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(reveal.exists)
        capture("32-standard-paper-returned")
        corner.press(forDuration: 0.1, thenDragTo: corner.withOffset(CGVector(dx: -80, dy: -88)), withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["ritual.journal"].waitForExistence(timeout: 5))
        capture("33-standard-paper-revealed")
    }

    func testPaperReduceMotionAndRevisitPreserveRevealedDay() {
        app.launchArguments += ["--test-reduce-motion"]
        begin()
        app.buttons["ritual.reveal"].tap()
        XCTAssertTrue(app.buttons["ritual.journal"].waitForExistence(timeout: 5))
        app.selectNotebookPage("静心")
        app.selectNotebookPage("今日")
        XCTAssertTrue(app.staticTexts["ritual.revealed"].exists)
        XCTAssertFalse(app.buttons["ritual.reveal"].exists)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["ritual.journal"].waitForExistence(timeout: 5))
        capture("34-reduced-motion-revisited")
    }

    func testBreathingAndBirthProfile() {
        begin(); app.selectNotebookPage("静心"); capture("07-calm")
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
        app.selectNotebookPage("我的"); capture("09-profile-empty")
        app.buttons["profile.addBirth"].tap()
        XCTAssertTrue(app.buttons["birth.save"].waitForExistence(timeout: 5)); capture("10-birth-editor")
        for _ in 0..<8 { if app.switches["birth.confirm"].isHittable { break }; app.swipeUp() }
        app.switches["birth.confirm"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["birth.save"].tap()
        XCTAssertTrue(app.staticTexts["profile.dossierReady"].waitForExistence(timeout: 25)); capture("11-profile")
        app.swipeUp()
        app.openProfessionalCharts()
        XCTAssertTrue(app.navigationBars["命盘手稿"].waitForExistence(timeout: 5)); capture("12-four-pillars")
        app.buttons["紫微"].tap(); capture("13-ziwei")
    }
    func testManagedAIRequiresLoginAndSettingsHaveNoProviderFields() {
        begin(); app.selectNotebookPage("问道"); capture("14-chat-empty")
        let input = app.textFields["chat.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("今天想慢一点。")
        app.buttons["发送"].tap()
        XCTAssertTrue(app.buttons["账户与登录"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "请先登录账户")).firstMatch.exists)
        capture("15-ai-login-needed")
        app.buttons["账户与登录"].tap()
        XCTAssertTrue(app.navigationBars["账户与云端资料"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["通过 Google 继续"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        app.openNotebookSettings()
        XCTAssertTrue(app.staticTexts["回信伙伴, DeepSeek Flash"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["服务地址"].exists)
        XCTAssertFalse(app.textFields["模型名称"].exists)
        XCTAssertFalse(app.secureTextFields["API Key"].exists)
        capture("16-settings")
        app.swipeUp(); app.buttons["晨间与节气提醒"].tap()
        capture("17-reminders")
    }
    func testDarkAndReducedMotionRitual() {
        app.launchArguments += ["--test-dark", "--test-reduce-motion"]
        begin(); capture("18-dark-paper")
        app.buttons["ritual.reveal"].tap()
        XCTAssertTrue(app.buttons["ritual.journal"].waitForExistence(timeout: 5)); capture("19-dark-revealed")
        app.selectNotebookPage("静心"); capture("20-dark-calm")
        for _ in 0..<4 { if app.buttons["开始"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.buttons["开始"].isHittable)
        app.buttons["开始"].tap()
        XCTAssertTrue(app.buttons["暂停"].waitForExistence(timeout: 5)); capture("23-dark-controls")
        app.selectNotebookPage("问道"); capture("27-dark-chat")
        XCTAssertTrue(app.textFields["chat.input"].isHittable)
        app.selectNotebookPage("我的"); capture("28-dark-profile")
        for _ in 0..<4 { if app.buttons["profile.addBirth"].isHittable { break }; app.swipeUp() }
        app.buttons["profile.addBirth"].tap()
        XCTAssertTrue(app.buttons["birth.save"].waitForExistence(timeout: 5))
        for _ in 0..<8 { if app.switches["birth.confirm"].isHittable { break }; app.swipeUp() }
        app.switches["birth.confirm"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["birth.save"].tap()
        XCTAssertTrue(app.staticTexts["profile.dossierReady"].waitForExistence(timeout: 25))
        app.swipeUp(); capture("29-dark-profile-reading")
    }
    func testCeladonTheme() {
        begin(); app.selectNotebookPage("我的")
        let settings = app.buttons["profile.settings"]
        for _ in 0..<8 { if settings.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(settings.isHittable); settings.tap()
        app.buttons["appearance.picker"].tap()
        app.buttons["青瓷"].tap()
        app.selectNotebookPage("今日"); capture("24-celadon-today")
        app.selectNotebookPage("静心"); capture("25-celadon-calm")
    }
}
