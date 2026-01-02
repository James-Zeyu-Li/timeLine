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
        
        let addButton = app.buttons["floatingAddButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()
        
        let addCardButton = app.buttons["addCardButton"]
        XCTAssertTrue(addCardButton.waitForExistence(timeout: 2))
        addCardButton.tap()
        
        let titleField = app.textFields["quickBuilderTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        if let existingValue = titleField.value as? String {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingValue.count)
            titleField.typeText(deleteString)
        }
        titleField.typeText("TaskModeTest")
        app.swipeUp()
        
        let reminderChip = app.buttons["quickBuilderTaskModeReminder"]
        XCTAssertTrue(reminderChip.waitForExistence(timeout: 2))
        reminderChip.tap()
        XCTAssertEqual(reminderChip.value as? String, "selected")

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
        
        let modePicker = app.segmentedControls["cardDetailTaskModePicker"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 2))
        XCTAssertEqual(modePicker.value as? String, "Reminder")
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
        let tasksLabel = app.staticTexts["Tasks"]
        
        let foundEndButton = endButton.waitForExistence(timeout: 3)
        let foundHeader = focusGroupHeader.exists
        let foundTasks = tasksLabel.exists
        
        // If GroupFocusView not found, we might be in BattleView instead
        if !foundEndButton && !foundHeader {
            // Check for BattleView elements as a fallback
            let retreatButton = app.buttons["Retreat"]
            XCTFail("GroupFocusView not displayed. Retreat button exists: \(retreatButton.exists)")
        }
        
        XCTAssertTrue(foundEndButton || foundHeader, "GroupFocusView should be displayed but neither endButton nor header found")
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
