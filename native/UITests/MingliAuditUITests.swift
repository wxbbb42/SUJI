import XCTest

/// Current-run audit evidence uses an ephemeral notebook and synthetic birth data.
final class MingliAuditUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--notebook-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func begin() {
        app.launch()
        XCTAssertTrue(app.buttons["nav.profile"].waitForExistence(timeout: 10))
        app.selectNotebookPage("我的")
        XCTAssertTrue(app.buttons["profile.addBirth"].waitForExistence(timeout: 10))
    }

    private func saveBirth() {
        let confirm = app.switches["birth.confirm"]
        if confirm.exists || !app.buttons["birth.save"].isEnabled {
            for _ in 0..<8 { if confirm.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(confirm.isHittable)
            confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        app.buttons["birth.save"].tap()
    }

    private func tapRow(_ title: String) {
        if title == "命盘手稿" { app.openProfessionalCharts(); return }
        if title == "人生的节奏" {
            app.selectNotebookPage("我的")
            app.buttons["profile.report"].tap()
            app.buttons["report.professional"].tap()
        } else if title == "校准出生时辰" || title == "关系里的我们" {
            app.selectNotebookPage("我的")
        }
        let row = app.buttons.containing(.staticText, identifier: title).firstMatch
        for _ in 0..<5 {
            if row.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(row.isHittable, "Missing row: \(title)")
        row.tap()
    }

    private func back() {
        app.navigationBars.buttons.firstMatch.tap()
    }

    private func revealButton(_ label: String) -> XCUIElement {
        let button = app.buttons[label].firstMatch
        for _ in 0..<8 { if button.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(button.isHittable, "Missing button: \(label)")
        return button
    }

    private func text(containing value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    func testCaptureMingliJourney() {
        begin()
        app.buttons["profile.addBirth"].tap()
        XCTAssertTrue(app.buttons["birth.save"].waitForExistence(timeout: 5))
        capture("01-birth-editor")
        saveBirth()
        XCTAssertTrue(app.staticTexts["profile.dossierReady"].waitForExistence(timeout: 25))
        capture("02-profile-reading")

        tapRow("命盘手稿")
        XCTAssertTrue(app.navigationBars["命盘手稿"].waitForExistence(timeout: 5))
        capture("03-four-pillars")
        revealButton("结构与关系").tap()
        XCTAssertTrue(text(containing: "扶抑参考").exists)
        XCTAssertTrue(text(containing: "格局用神：").exists)
        app.swipeUp()
        capture("04-chart-interpretation")
        revealButton("调候文献候选（条件待核）").tap()
        XCTAssertTrue(text(containing: "尚未自动选定调候用神").exists)
        app.swipeUp(); capture("16-tiaohou-source")
        revealButton("排盘口径与时间").tap()
        XCTAssertTrue(text(containing: "民用输入：").exists)
        app.swipeUp(); capture("17-calculation-policy")
        for _ in 0..<10 {
            let picker = app.buttons["紫微"]
            if picker.isHittable && picker.frame.minY > app.navigationBars.firstMatch.frame.maxY + 4 { break }
            app.swipeDown()
        }
        app.buttons["紫微"].tap()
        XCTAssertTrue(text(containing: "命宫在").waitForExistence(timeout: 5))
        capture("05-ziwei-palaces")
        let palace = app.buttons.containing(.staticText, identifier: "财帛宫").firstMatch
        XCTAssertTrue(palace.waitForExistence(timeout: 5)); palace.tap()
        XCTAssertTrue(app.navigationBars["财帛宫"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["完整辅星与杂曜"].exists)
        capture("14-ziwei-palace-detail")
        back()
        back()

        tapRow("人生的节奏")
        XCTAssertTrue(app.staticTexts["起运依据"].waitForExistence(timeout: 10))
        XCTAssertTrue(text(containing: "首运开始：").waitForExistence(timeout: 10))
        XCTAssertTrue(text(containing: "流年周期：").exists)
        capture("06-annual-decadal")
        app.swipeUp(); capture("15-qiyun-method")
        back()

        tapRow("校准出生时辰")
        XCTAssertTrue(app.buttons["采用这个时辰"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(text(containing: "1995年1月1日").exists)
        capture("07-calibration-candidates")
        revealButton("用经历作参照").tap()
        XCTAssertTrue(app.buttons["开始这段整理"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["开始这段整理"].isEnabled)
        XCTAssertTrue(app.buttons["账户与登录"].exists)
        capture("18-reflection-login")
        back()
        revealButton("查看历年差异线索").tap()
        XCTAssertTrue(text(containing: "八字：").exists)
        XCTAssertTrue(text(containing: "紫微：").exists)
        XCTAssertTrue(text(containing: "紫微大限转入本命").exists)
        XCTAssertFalse(text(containing: "紫微大限转正印").exists)
        app.swipeUp()
        capture("08-calibration-events")
        back()

        tapRow("关系里的我们")
        app.buttons["填写对方的出生资料"].tap()
        XCTAssertTrue(app.buttons["birth.save"].waitForExistence(timeout: 5))
        saveBirth()
        XCTAssertTrue(app.staticTexts["传统关系线索"].waitForExistence(timeout: 15))
        XCTAssertTrue(text(containing: "你的日柱：").exists)
        XCTAssertTrue(text(containing: "日干关系：").exists)
        XCTAssertTrue(text(containing: "日支关系：").exists)
        app.swipeUp()
        capture("09-relationship")

        app.selectNotebookPage("问道")
        XCTAssertTrue(app.textFields["chat.input"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["去登录"].exists)
        capture("10-chat-start")
        app.textFields["chat.input"].tap()
        app.textFields["chat.input"].typeText("请解释命盘依据")
        app.buttons["发送"].tap()
        XCTAssertTrue(app.buttons["账户与登录"].waitForExistence(timeout: 15))
        capture("11-chat-login-required")
    }


    func testCaptureFourTabsAndDarkPalaces() {
        begin()
        app.selectNotebookPage("今日"); capture("20-light-today")
        app.selectNotebookPage("静心"); capture("21-light-calm")
        revealButton("关于这些声音").tap()
        XCTAssertTrue(text(containing: "并非自然环境录音").exists)
        app.swipeUp(); capture("27-calm-sound-source")
        app.terminate()
        app.launchArguments += ["--test-dark"]
        begin()
        app.selectNotebookPage("今日"); capture("22-dark-today")
        app.selectNotebookPage("静心"); capture("23-dark-calm")
        app.selectNotebookPage("问道"); capture("24-dark-chat")
        app.selectNotebookPage("我的")
        app.buttons["profile.addBirth"].tap()
        XCTAssertTrue(app.buttons["birth.save"].waitForExistence(timeout: 5))
        saveBirth()
        XCTAssertTrue(app.staticTexts["profile.dossierReady"].waitForExistence(timeout: 25)); capture("25-dark-profile")
        tapRow("命盘手稿")
        app.buttons["紫微"].tap(); capture("26-dark-ziwei")
    }
}
