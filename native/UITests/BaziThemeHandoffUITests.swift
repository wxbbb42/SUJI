import XCTest

/// In-memory synthetic birth record; these tests do not call AI or a production account.
final class BaziThemeHandoffUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--notebook-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
    }
    private var input: XCUIElement {
        app.textFields["chat.input"].exists ? app.textFields["chat.input"] : app.textViews["chat.input"]
    }
    private func tap(_ id: String) {
        let target = app.buttons[id]
        reveal(target)
        XCTAssertTrue(target.isHittable, id)
        target.tap()
    }
    private func reveal(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: 3)
        // A large disclosure can put its earlier action ABOVE the viewport.
        // Use the actual target frame to choose direction and distance; never
        // assume repeated upward swipes will eventually find every control.
        for _ in 0..<16 {
            let screen = app.frame
            let target = element.exists ? element.frame : .zero
            // AX can report a partially clipped button as hittable even when
            // XCTest's center tap lands on the overlaid navigation bar.
            let reportBar = app.navigationBars["我的册页"]
            let chatBar = app.navigationBars["问道"]
            let composer = app.otherElements["chat.composer"]
            let themeContent = element.exists && element.identifier.hasPrefix("theme.")
            let chatContent = themeContent && !reportBar.exists && chatBar.exists && composer.exists
            let top = reportBar.exists ? reportBar.frame.maxY + 8 : chatContent ? chatBar.frame.maxY + 8 : screen.minY
            let bottom = chatContent ? composer.frame.minY - 8 : screen.maxY - 34
            let exposedButton = !themeContent || element.elementType != .button
                || (target.minY >= top && target.maxY <= bottom)
            if element.exists && element.isHittable && exposedButton { return }
            // At AX XXXL the composer occupies much of the screen. A generic
            // app swipe begins on it, so it cannot reveal the pending question.
            let height = bottom - top
            let midpoint = (top + bottom) / 2
            let downward = !target.isEmpty && target.midY < midpoint
            if reportBar.exists {
                // A short press-and-drag can activate a report action on iOS
                // 18 even at the gutter. A native scroll-view swipe cancels
                // the button press and stays inside the presented report.
                let scroll = app.scrollViews["report.scroll"]
                XCTAssertTrue(scroll.exists)
                if downward { scroll.swipeDown(velocity: .slow) }
                else { scroll.swipeUp(velocity: .slow) }
                XCTAssertTrue(reportBar.exists, "Scrolling must not activate a report action")
                continue
            }
            let distance = target.isEmpty ? height * 0.42
                : min(height * 0.5, max(80, abs(target.midY - midpoint)))
            let startY = top + height * (downward ? 0.25 : 0.75)
            let endY = startY + (downward ? 1 : -1) * distance
            // Keep the gesture in the scroll view's leading gutter. On iOS
            // 18 a drag starting on a plain NavigationLink can activate it,
            // taking the test out of the profile before birth entry.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: startY / screen.height))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: endY / screen.height))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        let diagnostic = element.exists ? String(describing: element.frame) : "not present in the accessibility tree"
        XCTAssertTrue(element.exists && element.isHittable, "Target is not reachable: \(diagnostic)")
    }
    private func openSyntheticReport() {
        tap("nav.profile")
        let birth = app.buttons["profile.addBirth"]
        XCTAssertTrue(birth.waitForExistence(timeout: 10))
        // Match NatalReadingReportUITests' successful iOS 18 profile path.
        // A short press-and-drag can activate the large NavigationLink even
        // from its gutter; XCTest's native swipe cancels that press correctly.
        for _ in 0..<9 { if birth.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(birth.isHittable); birth.tap()
        let confirm = app.switches["birth.confirm"]
        for _ in 0..<12 { if confirm.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(confirm.isHittable)
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        tap("birth.save")
        XCTAssertTrue(app.staticTexts["profile.dossierReady"].waitForExistence(timeout: 30))
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
        XCTAssertTrue(app.navigationBars["我的册页"].waitForExistence(timeout: 10))
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func dismissKeyboardIfShown() {
        // Fresh iOS 18 CI simulators show this system introduction when a
        // suggestion focuses the composer without XCTest typing into it.
        // It covers the keyboard toolbar; scrolling app content cannot close it.
        let introduction = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if introduction.waitForExistence(timeout: 2) {
            let next = app.buttons["Continue"]
            XCTAssertTrue(next.waitForExistence(timeout: 5) && next.isHittable)
            next.tap()
            let gone = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: introduction)
            XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed)
        }
        if app.keyboards.firstMatch.exists {
            let dismiss = app.buttons["chat.dismissKeyboard"]
            let ready = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true AND hittable == true"), object: dismiss)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
            dismiss.tap()
            let hidden = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
            XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed)
        }
    }
    private func assertComposerDoesNotOverlapNavigation() {
        XCTAssertFalse(app.tabBars.firstMatch.exists, "The system tab bar must not duplicate the notebook navigation")
        let bar = app.otherElements["nav.bar"]
        let send = app.buttons["chat.send"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        XCTAssertTrue(input.exists && send.exists)
        XCTAssertGreaterThanOrEqual(send.frame.height, 44)
        XCTAssertGreaterThanOrEqual(send.frame.width, 44)
        XCTAssertLessThanOrEqual(input.frame.maxY, bar.frame.minY + 1, "The entire input must remain above the navigation background")
        XCTAssertLessThanOrEqual(send.frame.maxY, bar.frame.minY + 1, "The entire send circle must remain above the navigation background")
        XCTAssertTrue(input.isHittable)
        let marker = app.staticTexts["notebook.gate.observedGap"]
        if marker.exists {
            XCTAssertLessThanOrEqual(marker.frame.maxY, app.navigationBars["问道"].frame.minY + 1, "The debug label must not cover the navigation bar")
        }
    }
    func testThemeHandoffPreservesDraftAndReturnsToReport() {
        app.launch(); tap("nav.chat")
        XCTAssertTrue(input.waitForExistence(timeout: 10)); input.tap(); input.typeText("我想保留这段尚未发送的话")
        tap("nav.profile")
        tap("profile.close")
        openSyntheticReport()
        reveal(app.staticTexts["theme.boundary"])
        tap("theme.expand"); capture("theme-01-reading")
        tap("theme.continue")
        XCTAssertTrue(app.buttons["theme.pending.cancel"].waitForExistence(timeout: 10))
        XCTAssertEqual(input.value as? String, "我想保留这段尚未发送的话")
        XCTAssertFalse(app.buttons["theme.pending.usePrompt"].exists, "A report must not replace a nonempty draft")
        assertComposerDoesNotOverlapNavigation()
        capture("theme-02-handoff-draft")
        tap("theme.pending.return")
        XCTAssertTrue(app.navigationBars["我的册页"].waitForExistence(timeout: 10))
        reveal(app.staticTexts["theme.boundary"])
        capture("theme-03-returned-report")
        tap("profile.close")
        XCTAssertEqual(input.value as? String, "我想保留这段尚未发送的话")
        tap("theme.pending.cancel")
        XCTAssertEqual(input.value as? String, "我想保留这段尚未发送的话")
        XCTAssertFalse(app.buttons["theme.pending.cancel"].exists)
    }
    func testDarkThemeCanBeReadAndQuestionChosenExplicitly() {
        app.launchArguments += ["--test-dark"]
        app.launch(); openSyntheticReport()
        reveal(app.staticTexts["theme.boundary"])
        tap("theme.expand"); capture("theme-04-dark-reading")
        XCTAssertEqual(app.buttons["theme.expand"].value as? String, "已展开")
        tap("theme.example")
        XCTAssertEqual(app.buttons["theme.example"].value as? String, "已展开")
        let example = app.staticTexts["theme.example.text"]
        reveal(example)
        XCTAssertTrue(example.isHittable)
        XCTAssertGreaterThan(example.label.count, 40, "The expanded example must contain the actual local reading")
        capture("theme-04b-dark-example")
        tap("theme.example")
        XCTAssertEqual(app.buttons["theme.example"].value as? String, "已收起")
        tap("theme.sources")
        XCTAssertEqual(app.buttons["theme.sources"].value as? String, "已展开")
        let sourceQuote = app.staticTexts["theme.source.quote.ziping-theme-composition-v1"]
        reveal(sourceQuote)
        XCTAssertTrue(sourceQuote.isHittable)
        XCTAssertTrue(sourceQuote.label.contains("全在配合"))
        capture("theme-05-dark-source")
        let sourceScope = app.staticTexts["theme.source.scope.ziping-theme-composition-v1"]
        reveal(sourceScope)
        XCTAssertTrue(sourceScope.isHittable)
        XCTAssertTrue(sourceScope.label.contains("不支持"))
        capture("theme-05b-dark-source-boundary")
        tap("theme.sources")
        XCTAssertEqual(app.buttons["theme.sources"].value as? String, "已收起")
        tap("theme.continue.footer")
        XCTAssertTrue(app.buttons["theme.pending.usePrompt"].waitForExistence(timeout: 10))
        assertComposerDoesNotOverlapNavigation()
        capture("theme-06-dark-handoff")
        tap("theme.pending.usePrompt")
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        XCTAssertFalse((input.value as? String ?? "").isEmpty)
        XCTAssertFalse(app.staticTexts["chat.failure"].exists, "Choosing a suggestion must not send it")
        dismissKeyboardIfShown()
        capture("theme-06b-dark-filled-draft")
        tap("theme.pending.return")
        XCTAssertTrue(app.navigationBars["我的册页"].waitForExistence(timeout: 10))
        capture("theme-07-dark-return")
    }
    func testBirthReconfirmationExpiresThemeWithoutClearingDraft() {
        app.launch(); openSyntheticReport(); reveal(app.staticTexts["theme.boundary"])
        tap("theme.continue")
        XCTAssertTrue(input.waitForExistence(timeout: 10)); input.tap(); input.typeText("这段草稿在资料变更后也要保留")
        tap("nav.profile"); tap("profile.addBirth"); tap("birth.save")
        XCTAssertTrue(app.buttons["profile.close"].waitForExistence(timeout: 30))
        tap("profile.close")
        XCTAssertTrue(app.staticTexts["theme.expired"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["theme.pending.cancel"].exists)
        XCTAssertEqual(input.value as? String, "这段草稿在资料变更后也要保留")
        assertComposerDoesNotOverlapNavigation()
        capture("theme-08-expired-draft")
    }
    func testProductionDossierGateRetainsDraftDuringActualBirthChange() {
        // This fixture replaces login only, unlike --notebook-fixtures. The
        // first birth form, real local calculation and dossier gate remain on.
        app.launchArguments.removeAll { $0 == "--notebook-fixtures" }
        app.launchArguments += ["--notebook-gated-fixture"]
        app.launch()
        XCTAssertTrue(app.navigationBars["建立你的档案"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["nav.chat"].exists)
        let confirm = app.switches["birth.confirm"]
        for _ in 0..<12 { if confirm.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(confirm.isHittable)
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        tap("birth.save")
        XCTAssertTrue(app.buttons["nav.chat"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["notebook.gate.active"].exists)
        tap("nav.chat")
        input.tap(); input.typeText("真实档案重建期间保留这段合成草稿")
        tap("nav.profile"); tap("profile.addBirth")
        XCTAssertTrue(app.navigationBars["出生资料"].waitForExistence(timeout: 10))
        let city = app.textFields["birth.city"]
        reveal(city); city.tap()
        city.typeText("·合成资料改动")
        tap("birth.save")
        XCTAssertTrue(app.staticTexts["profile.dossierReady"].waitForExistence(timeout: 30))
        tap("profile.close")
        XCTAssertTrue(app.staticTexts["notebook.gate.observedGap"].waitForExistence(timeout: 10), "The app must observe a real hasNatalDossier=false interval, not just a same-value save")
        XCTAssertEqual(input.value as? String, "真实档案重建期间保留这段合成草稿")
        assertComposerDoesNotOverlapNavigation()
        capture("theme-09-production-gate-draft")
    }
    func testChoosingAnotherConversationModeDetachesThemeAndKeepsDraft() {
        app.launch(); openSyntheticReport(); reveal(app.staticTexts["theme.boundary"])
        tap("theme.continue")
        XCTAssertTrue(app.buttons["theme.pending.cancel"].waitForExistence(timeout: 10))
        input.tap(); input.typeText("我现在只想聊一聊最近的心情")
        dismissKeyboardIfShown()
        let mode = app.segmentedControls["chat.mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 10)); mode.buttons["倾诉"].tap()
        XCTAssertTrue(mode.buttons["倾诉"].isSelected)
        XCTAssertFalse(app.buttons["theme.pending.cancel"].exists)
        XCTAssertEqual(input.value as? String, "我现在只想聊一聊最近的心情")
        assertComposerDoesNotOverlapNavigation()
        capture("theme-10-explicit-mode")
    }
}
