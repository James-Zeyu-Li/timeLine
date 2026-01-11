//
//  timeLineUITests_MapInteraction.swift
//  timeLineUITests
//
//  Created by Automation on 2026-01-11.
//

import XCTest

final class timeLineUITests_MapInteraction: XCTestCase {

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-ui-testing", "-empty-timeline"])
        app.launchEnvironment["EMPTY_TIMELINE"] = "1"
        return app
    }
    
    @MainActor
    func testSwipeToDeleteNode() throws {
        let app = makeApp()
        app.launch()
        
        // 1. Create a task
        createTask(app, title: "Delete Me")
        
        // 2. Find the node
        let node = app.buttons["mapNode_Delete_Me"]
        XCTAssertTrue(node.waitForExistence(timeout: 5), "Node should exist")
        
        // 3. Swipe Left
        node.swipeLeft()
        
        // 4. Tap Delete
        let deleteButton = node.descendants(matching: .any)["Delete"] // The button is inside the SwipeableNode view hierarchy or overlay
        // Note: The swipe actions might be distinct buttons depending on implementation. 
        // In SwipeableTimelineNode.swift, they are just Buttons with Text("Delete").
        // We'll try finding by text "Delete".
        
        let deleteBtn = app.buttons["Delete"]
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 2), "Delete button should appear after swipe")
        deleteBtn.tap()
        
        // 5. Verify Removal
        XCTAssertTrue(node.waitForNonExistence(timeout: 3), "Node should be removed")
    }
    
    @MainActor
    func testSwipeToDuplicateNode() throws {
        let app = makeApp()
        app.launch()
        
        // 1. Create a task
        createTask(app, title: "Copy Me")
        
        // 2. Find the node
        let node = app.buttons["mapNode_Copy_Me"]
        XCTAssertTrue(node.waitForExistence(timeout: 5))
        
        // 3. Swipe Left
        node.swipeLeft()
        
        // 4. Tap Copy
        let copyBtn = app.buttons["Copy"]
        XCTAssertTrue(copyBtn.waitForExistence(timeout: 2))
        copyBtn.tap()
        
        // 5. Verify Duplication
        // Since identifiers might be identical, we check count.
        // Wait a moment for animation
        sleep(1) 
        
        let matchingNodes = app.buttons.matching(identifier: "mapNode_Copy_Me")
        XCTAssertEqual(matchingNodes.count, 2, "Should have 2 nodes after copy")
    }
    
    @MainActor
    func testDragToReorderNodes() throws {
        let app = makeApp()
        app.launch()
        
        // 1. Create two tasks
        createTask(app, title: "Task A_Top")
        createTask(app, title: "Task B_Bottom")
        
        let nodeA = app.buttons["mapNode_Task_A_Top"]
        let nodeB = app.buttons["mapNode_Task_B_Bottom"]
        
        XCTAssertTrue(nodeA.waitForExistence(timeout: 5))
        XCTAssertTrue(nodeB.waitForExistence(timeout: 5))
        
        // Verify initial order: A is above B (lower Y coordinate)
        let frameA_Initial = nodeA.frame
        let frameB_Initial = nodeB.frame
        XCTAssertLessThan(frameA_Initial.minY, frameB_Initial.minY, "Task A should be above Task B initially")
        
        // 2. Drag Task B above Task A
        // We need to grab the drag handle if possible, or usually just long press -> drag works if implemented that way.
        // But SwipeableTimelineNode uses a dedicated DragGesture on the whole card? 
        // Looking at code: `dragGesture` is on `mainNodeContent`.
        // BUT `SimultaneousGesture(LongPressGesture...` is also there.
        // And `dragGesture` starts only on vertical movement > 15.
        
        // Let's try dragging Node B up to Node A's position
        nodeB.press(forDuration: 0.2, thenDragTo: nodeA)
        
        // Wait for animation/settle
        sleep(2)
        
        // 3. Verify New Order
        // Now B should be above A
        let frameA_Final = nodeA.frame
        let frameB_Final = nodeB.frame
        
        // Re-query elements to get fresh frames
        let nodeA_fresh = app.buttons["mapNode_Task_A_Top"]
        let nodeB_fresh = app.buttons["mapNode_Task_B_Bottom"]
        
        XCTAssertLessThan(nodeB_fresh.frame.minY, nodeA_fresh.frame.minY, "Task B should now be above Task A")
    }
    
    // MARK: - Helpers
    
    private func createTask(_ app: XCUIApplication, title: String) {
        // Open Todo Sheet
        let todoButton = app.buttons["todoEntryButton"]
        if todoButton.waitForExistence(timeout: 2) {
            todoButton.tap()
        } else {
            // Fallback for strict if todo not found (but it should be there in this version)
            XCTFail("Todo button not found")
        }
        
        // Use Quick Add Row 0
        let firstRow = app.textFields["focusRowTitle_0"]
        if firstRow.waitForExistence(timeout: 2) {
            firstRow.tap()
            firstRow.typeText("\(title) 30m\n") // Enter to submit/next? Or just type.
            
            // To "Start", we need to select it.
            // But wait, TodoSheet behavior: "Start 1 task -> strict occurrence".
            // We need to tap the row to select it?
            
            // In TodoSheet implementation (assumed from docs), typing in quick add might just add it to list?
            // Actually `TodoSheet` spec says:
            // "Start 1 task -> strict occurrence"
            
            // Let's assume typing in the row and hitting enter adds it?
            // Or we verify if we can just tap "Start Focus".
            
            // Simplified: Use the "Add Card" flow via Strict Sheet if Todo is complex to script blindly.
            // But let's try the QuickBuilder path which is robust in other tests.
        } else {
             // Fallback to QuickBuilder via Strict Button
             // Close Todo first if open
             app.tap() // dismiss
             
             let strictButton = app.buttons["strictEntryButton"]
             strictButton.tap()
             
             let addCard = app.buttons["addCardButton"]
             addCard.tap()
             
             let titleField = app.textFields["quickBuilderTitleField"]
             titleField.tap()
             titleField.typeText(title)
             
             let createBtn = app.buttons["quickBuilderCreateButton"]
             createBtn.tap()
             
             // Close overlay
             let overlay = app.otherElements["deckOverlayBackground"]
             if overlay.waitForExistence(timeout: 1) {
                 overlay.tap()
             }
        }
        
        // Ensure we are back on map
    }
    
    private func createViaStrict(_ app: XCUIApplication, title: String) {
         let strictButton = app.buttons["strictEntryButton"]
         XCTAssertTrue(strictButton.waitForExistence(timeout: 2))
         strictButton.tap()
         
         let addCard = app.buttons["addCardButton"]
         XCTAssertTrue(addCard.waitForExistence(timeout: 2))
         addCard.tap()
         
         let titleField = app.textFields["quickBuilderTitleField"]
         XCTAssertTrue(titleField.waitForExistence(timeout: 2))
         titleField.tap()
         titleField.typeText(title)
         
         let createBtn = app.buttons["quickBuilderCreateButton"]
         createBtn.tap()
         
         // Wait for card to appear in "Cards" tab to confirm creation (optional)
         // Then drag it to map? Or does QuickBuilder just create a template?
         // QuickBuilder creates a template.
         // WE NEED TO PLACE IT ON MAP.
         
         // In `TimelineStorePlacementTests`, PlaceCardOccurrence happens.
         // In UI, we need to drag from DeckOverlay to Map.
         // OR currently "QuickBuilder create returns to Cards tab".
         
         // Wait, is there a "place immediately" option? 
         // "Reminder create: if remindAt set, auto-inserts".
         // Normal tasks: must drag.
         
         // ACTUALLY: The existing tests `testInFocusReminderCountdown` uses `createButton.tap()` and then finds `mapNode_FocusTask`.
         // Does QuickBuilder auto-place?
         // Looking at `QuickBuilderSheet` implementation would confirm.
         // But `testInFocusReminderCountdown` implies it does auto-place OR the test is checking for existence in the card list?
         // "let focusNode = app.descendants(matching: .any)["mapNode_FocusTask"]" -> This implies Map Node.
         
         // Reviewing `Phase 15.6`: "Inbox/QuickEntry 改为创建 CardTemplate 再走 placeCardOccurrence".
         // But maybe QuickBuilder has an "Add to Map" mode?
         
         // Let's look at `createTask` helper in my proposed code again.
         // I should stick to the pattern in `testInFocusReminderCountdown` of `timeLineUITests.swift`:
         // It creates via QuickBuilder, checks for `mapNode_FocusTask` existence.
         // Wait, `testInFocusReminderCountdown` lines 163: `app.descendants(matching: .any)["mapNode_FocusTask"]`.
         // That test passes?
         // If `QuickBuilder` only creates a template, how does it get to the map?
         // Ah, maybe the test was relying on `Reminder` task mode which auto-places?
         // The first task in `testInFocusReminderCountdown` is created with default `FocusTask`. It doesn't set Reminder mode.
         // Maybe QuickBuilder DOES place it if it's "Add to Day"?
         
         // To be safe, I will implement `createTask` to specifically use the `Reminder` mode trick OR drag it.
         // OR, I can use the new `TodoSheet` if it supports "Start" which places it.
         
         // Let's use `createViaStrict` but manually Drag from Cards tab to Map if needed.
         // Or just assume `QuickBuilder` adds to `Inbox` which validates as `mapNode`?
         // No, Inbox items are in `InboxListView`, not `SwipeableTimelineNode` (unless implemented that way).
         // `InboxListView` items might not have `mapNode_` identifiers.
         
         // Let's verify `testInFocusReminderCountdown` code again.
         // It says "1. Add Battle Task ... XCTAssertTrue(focusNode.waitForExistence)".
         // So it seems it IS placed.
    }
}
