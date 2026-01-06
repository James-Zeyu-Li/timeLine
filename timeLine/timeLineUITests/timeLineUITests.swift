//
//  timeLineUITests.swift
//  timeLineUITests
//
//  Created by Zeyu Li on 12/21/25.
//

import XCTest

final class timeLineUITests: XCTestCase {

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        return app
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        let doneButton = app.keyboards.buttons["Done"]
        if doneButton.exists {
            doneButton.tap()
            return
        }
        let returnButton = app.keyboards.buttons["Return"]
        if returnButton.exists {
            returnButton.tap()
            return
        }
        let taskModeHeader = app.staticTexts["Task Mode"]
        if taskModeHeader.exists {
            taskModeHeader.tap()
            return
        }
        app.tap()
    }
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = makeApp()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = makeApp()
            app.launch()
        }
    }
    
    @MainActor
    func testQuickBuilderTaskModePersistsToEditSheet() throws {
        let app = makeApp()
        app.launch()
        
        openQuickBuilder(in: app)
        
        let titleField = app.textFields["quickBuilderTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        if let existingValue = titleField.value as? String {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingValue.count)
            titleField.typeText(deleteString)
        }
        titleField.typeText("TaskModeTest")

        dismissKeyboard(in: app)
        let modePicker = app.segmentedControls["quickBuilderTaskModePicker"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 2))
        modePicker.buttons["Reminder"].tap()

        app.swipeUp()
        let createButton = app.buttons["quickBuilderCreateButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 2))
        createButton.tap()
        
        let cardId = "cardView_TaskModeTest"
        let card = app.descendants(matching: .any)[cardId]
        XCTAssertTrue(card.waitForExistence(timeout: 4))
        card.press(forDuration: 1.0)
        
        let editTitleField = app.textFields["cardDetailTitleField"]
        XCTAssertTrue(editTitleField.waitForExistence(timeout: 2))
        XCTAssertEqual(editTitleField.value as? String, "TaskModeTest")
        
        let detailModePicker = app.segmentedControls["cardDetailTaskModePicker"]
        XCTAssertTrue(detailModePicker.waitForExistence(timeout: 2))
        XCTAssertEqual(detailModePicker.value as? String, "Reminder")
    }
    
    @MainActor
    func testMapLongPressEditsTask() throws {
        let app = makeApp()
        app.launch()
        
        let targetNode = app.buttons["mapNode_Morning_Email"]
        XCTAssertTrue(targetNode.waitForExistence(timeout: 3))
        targetNode.press(forDuration: 1.0)
        
        let editTitleField = app.textFields["taskSheetTitleField"]
        XCTAssertTrue(editTitleField.waitForExistence(timeout: 2))
        editTitleField.tap()
        if let existingValue = editTitleField.value as? String {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingValue.count)
            editTitleField.typeText(deleteString)
        }
        editTitleField.typeText("Morning Email Updated")
        
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()
        
        let renamedNode = app.buttons["mapNode_Morning_Email_Updated"]
        XCTAssertTrue(renamedNode.waitForExistence(timeout: 3))
    }

    @MainActor
    func testInFocusReminderCountdown() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-ui-testing", "-empty-timeline"])
        app.launchEnvironment["EMPTY_TIMELINE"] = "1"
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        
        // 1. Add Battle Task
        let addButton = app.buttons["floatingAddButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()
        
        let addCardButton = app.buttons["addCardButton"]
        XCTAssertTrue(addCardButton.waitForExistence(timeout: 2))
        addCardButton.tap()
        
        let titleField = app.textFields["quickBuilderTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        replaceText(in: titleField, with: "FocusTask")
        
        let createButton = app.buttons["quickBuilderCreateButton"]
        createButton.tap()
        
        // Wait for sheet to dismiss
        XCTAssertTrue(titleField.waitForNonExistence(timeout: 5))

        closeDeckOverlayIfNeeded(in: app)
        
        let focusNode = app.descendants(matching: .any)["mapNode_FocusTask"]
        XCTAssertTrue(focusNode.waitForExistence(timeout: 8))
        
        // 2. Add Reminder Task (Upcoming)
        openQuickBuilder(in: app)
        
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        replaceText(in: titleField, with: "ReminderTask")

        dismissKeyboard(in: app)
        let modePicker = app.segmentedControls["quickBuilderTaskModePicker"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 2))
        modePicker.buttons["Reminder"].tap()
        app.swipeUp()
        
        createButton.tap()

        XCTAssertTrue(titleField.waitForNonExistence(timeout: 5))
        closeDeckOverlayIfNeeded(in: app)
        
        // 3. Start Battle Task
        XCTAssertTrue(focusNode.waitForExistence(timeout: 4))
        makeHittable(focusNode, in: app)
        focusNode.tap()
        
        // 4. Verify Battle View and Countdown
        let sessionLabel = app.staticTexts["FOCUS SESSION"]
        XCTAssertTrue(sessionLabel.waitForExistence(timeout: 4))
        
        // "距离 ReminderTask 还有"
        let predicate = NSPredicate(format: "label CONTAINS '距离 ReminderTask 还有'")
        let countdownLabel = app.staticTexts.element(matching: predicate)
        XCTAssertTrue(countdownLabel.waitForExistence(timeout: 4))
    }

    @MainActor
    func testGroupFocusShowsCompletedExplorationLabel() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-ui-testing", "-empty-timeline"])
        app.launchEnvironment["EMPTY_TIMELINE"] = "1"
        app.launch()

        let addButton = app.buttons["floatingAddButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        let libraryTab = app.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 2))
        libraryTab.tap()

        let addFromCards = app.buttons["Add from Cards"]
        XCTAssertTrue(addFromCards.waitForExistence(timeout: 2))
        addFromCards.tap()

        let emailRow = app.staticTexts["Email"].firstMatch
        XCTAssertTrue(emailRow.waitForExistence(timeout: 2))
        emailRow.tap()

        let codingRow = app.staticTexts["Coding"].firstMatch
        XCTAssertTrue(codingRow.waitForExistence(timeout: 2))
        codingRow.tap()

        let addToLibrary = app.buttons["Add to Library"].firstMatch
        XCTAssertTrue(addToLibrary.waitForExistence(timeout: 2))
        addToLibrary.tap()

        let selectButton = app.buttons["Select"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 2))
        selectButton.tap()

        let emailLibraryRow = app.staticTexts["Email"].firstMatch
        XCTAssertTrue(emailLibraryRow.waitForExistence(timeout: 2))
        emailLibraryRow.tap()

        let codingLibraryRow = app.staticTexts["Coding"].firstMatch
        XCTAssertTrue(codingLibraryRow.waitForExistence(timeout: 2))
        codingLibraryRow.tap()

        let addToGroup = app.buttons["Add to Group"]
        XCTAssertTrue(addToGroup.waitForExistence(timeout: 2))
        addToGroup.tap()

        let overlayBackground = app.otherElements["deckOverlayBackground"]
        if overlayBackground.waitForExistence(timeout: 1) {
            overlayBackground.tap()
            _ = waitForDisappearance(overlayBackground, timeout: 2)
        }

        // Allow time for engine state transition and view change
        Thread.sleep(forTimeInterval: 1.0)

        // Try finding GroupFocusView elements
        let endButton = app.buttons["完成今日探险"]
        let focusGroupHeader = app.staticTexts["FOCUS GROUP"]
        let foundEndButton = endButton.waitForExistence(timeout: 3)
        let foundHeader = focusGroupHeader.exists
        // If GroupFocusView not found, we might be in BattleView instead
        if !foundEndButton && !foundHeader {
            // Check for BattleView elements as a fallback
            let retreatButton = app.buttons["Retreat"]
            XCTFail("GroupFocusView not displayed. Retreat button exists: \(retreatButton.exists)")
        }
        
        XCTAssertTrue(foundEndButton || foundHeader, "GroupFocusView should be displayed but neither endButton nor header found")
    }

    @MainActor
    func testFocusListCreatesGroupFromRows() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-ui-testing", "-empty-timeline"])
        app.launchEnvironment["EMPTY_TIMELINE"] = "1"
        app.launch()

        let focusListButton = app.buttons["focusListButton"]
        XCTAssertTrue(focusListButton.waitForExistence(timeout: 2))
        focusListButton.tap()

        let firstRow = app.textFields["focusRowTitle_0"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 2))
        firstRow.tap()
        firstRow.typeText("Math 45m\n")

        let secondRow = app.textFields["focusRowTitle_1"]
        if !secondRow.waitForExistence(timeout: 1.5) {
            let addRow = app.buttons["focusListAddRow"]
            XCTAssertTrue(addRow.waitForExistence(timeout: 1))
            addRow.tap()
            XCTAssertTrue(secondRow.waitForExistence(timeout: 1))
        }
        secondRow.tap()
        secondRow.typeText("English 30m")

        dismissKeyboard(in: app)

        let parsedDuration = app.staticTexts["focusRowParsedDuration_0"]
        XCTAssertTrue(parsedDuration.waitForExistence(timeout: 1))

        let startGroup = app.buttons["Start Group Focus"]
        XCTAssertTrue(startGroup.waitForExistence(timeout: 2))
        startGroup.tap()

        let focusListSheet = app.otherElements["focusListSheet"]
        XCTAssertTrue(focusListSheet.waitForNonExistence(timeout: 4))
    }

    @MainActor
    func testFocusListParsesCombinedDuration() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-ui-testing", "-empty-timeline"])
        app.launchEnvironment["EMPTY_TIMELINE"] = "1"
        app.launch()

        let focusListButton = app.buttons["focusListButton"]
        XCTAssertTrue(focusListButton.waitForExistence(timeout: 2))
        focusListButton.tap()

        let firstRow = app.textFields["focusRowTitle_0"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 2))
        firstRow.tap()
        firstRow.typeText("Math 1h30m")

        dismissKeyboard(in: app)

        let parsedDuration = app.staticTexts["focusRowParsedDuration_0"]
        XCTAssertTrue(parsedDuration.waitForExistence(timeout: 1))
        XCTAssertEqual(parsedDuration.label, "1h 30m")
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func closeDeckOverlayIfNeeded(in app: XCUIApplication) {
        let overlayBackground = app.otherElements["deckOverlayBackground"]
        if overlayBackground.waitForExistence(timeout: 1) {
            overlayBackground.tap()
            _ = waitForDisappearance(overlayBackground, timeout: 2)
        }
    }

    private func openQuickBuilder(in app: XCUIApplication) {
        let addCardButton = app.buttons["addCardButton"]
        if !addCardButton.waitForExistence(timeout: 1) {
            let addButton = app.buttons["floatingAddButton"]
            XCTAssertTrue(addButton.waitForExistence(timeout: 2))
            addButton.tap()
            XCTAssertTrue(addCardButton.waitForExistence(timeout: 2))
        }
        addCardButton.tap()
    }

    private func makeHittable(_ element: XCUIElement, in app: XCUIApplication) {
        guard !element.isHittable else { return }
        for _ in 0..<3 {
            app.swipeUp()
            if element.isHittable { return }
        }
        for _ in 0..<3 {
            app.swipeDown()
            if element.isHittable { return }
        }
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        if let existingValue = field.value as? String {
            let placeholder = field.placeholderValue ?? ""
            if existingValue != placeholder {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingValue.count)
                field.typeText(deleteString)
            }
        }
        field.typeText(text)
    }
}
