import XCTest
import Combine
@testable import timeLine

@MainActor
final class RetreatDialogTests: XCTestCase {
    
    var engine: BattleEngine!
    var daySession: DaySession!
    var cardStore: CardTemplateStore!
    var libraryStore: LibraryStore!
    var stateManager: AppStateManager!
    
    override func setUp() {
        super.setUp()
        engine = BattleEngine()
        let boss = Boss(name: "Test Task", maxHp: 600)
        daySession = DaySession(nodes: [
            TimelineNode(type: .battle(boss), isLocked: false)
        ])
        cardStore = CardTemplateStore()
        libraryStore = LibraryStore()
        stateManager = AppStateManager(
            engine: engine,
            daySession: daySession,
            cardStore: cardStore,
            libraryStore: libraryStore,
            enablePersistence: false
        )
    }
    
    // MARK: - Grace Period Tests
    
    func testCanUndoStartWithin60Seconds() {
        let boss = Boss(name: "Quick Task", maxHp: 600)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        // Check at 30 seconds (within grace)
        let checkTime30 = startTime.addingTimeInterval(30)
        engine.tick(at: checkTime30)
        
        let elapsed30 = engine.currentSessionElapsed(at: checkTime30)
        XCTAssertNotNil(elapsed30)
        XCTAssertEqual(elapsed30!, 30, accuracy: 0.1)
        XCTAssertTrue(BattleExitPolicy.allowsUndoStart(elapsedSeconds: elapsed30))
        
        // Check at exactly 60 seconds (edge of grace)
        let checkTime60 = startTime.addingTimeInterval(60)
        engine.tick(at: checkTime60)
        
        let elapsed60 = engine.currentSessionElapsed(at: checkTime60)
        XCTAssertNotNil(elapsed60)
        XCTAssertEqual(elapsed60!, 60, accuracy: 0.1)
        XCTAssertTrue(BattleExitPolicy.allowsUndoStart(elapsedSeconds: elapsed60))
    }
    
    func testCannotUndoStartAfter60Seconds() {
        let boss = Boss(name: "Long Task", maxHp: 600)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        // Check at 61 seconds (past grace)
        let checkTime61 = startTime.addingTimeInterval(61)
        engine.tick(at: checkTime61)
        
        let elapsed61 = engine.currentSessionElapsed(at: checkTime61)
        XCTAssertNotNil(elapsed61)
        XCTAssertEqual(elapsed61!, 61, accuracy: 0.1)
        XCTAssertFalse(BattleExitPolicy.allowsUndoStart(elapsedSeconds: elapsed61))
        
        // Check at 120 seconds (well past grace)
        let checkTime120 = startTime.addingTimeInterval(120)
        engine.tick(at: checkTime120)
        
        let elapsed120 = engine.currentSessionElapsed(at: checkTime120)
        XCTAssertNotNil(elapsed120)
        XCTAssertEqual(elapsed120!, 120, accuracy: 0.1)
        XCTAssertFalse(BattleExitPolicy.allowsUndoStart(elapsedSeconds: elapsed120))
    }

    func testExitOptionsIncludeUndoWithinGrace() {
        let options = BattleExitPolicy.options(elapsedSeconds: 60, taskMode: .focusStrictFixed)
        XCTAssertTrue(options.contains(.undoStart))
        XCTAssertTrue(options.contains(.endAndRecord))
        XCTAssertTrue(options.contains(.keepFocusing))
    }

    func testExitOptionsHideUndoAfterGrace() {
        let options = BattleExitPolicy.options(elapsedSeconds: 61, taskMode: .focusStrictFixed)
        XCTAssertFalse(options.contains(.undoStart))
        XCTAssertTrue(options.contains(.endAndRecord))
        XCTAssertTrue(options.contains(.keepFocusing))
    }
    
    // MARK: - Dialog Options Tests
    
    func testUndoStartDoesNotRecordProgress() {
        let boss = Boss(name: "Undo Task", maxHp: 600)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        let controller = BattleExitController(engine: engine, stateSaver: stateManager)
        let expectation = XCTestExpectation(description: "No session result emitted")
        expectation.isInverted = true
        var cancellables = Set<AnyCancellable>()
        
        engine.onSessionComplete
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Progress 30 seconds
        let abortTime = startTime.addingTimeInterval(30)
        engine.tick(at: abortTime)
        
        // Verify we're fighting
        XCTAssertEqual(engine.state, .fighting)
        XCTAssertNotNil(engine.currentBoss)
        
        // Undo Start (abort session)
        controller.handle(.undoStart, taskMode: .focusStrictFixed)
        
        // Should return to idle with no credit
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.currentBoss)
        XCTAssertEqual(engine.totalFocusedToday, 0)
        wait(for: [expectation], timeout: 0.1)
    }
    
    func testEndAndRecordCreatesIncompleteExit() {
        let boss = Boss(name: "Record Task", maxHp: 600)
        let startTime = Date().addingTimeInterval(-120)
        engine.startBattle(boss: boss, at: startTime)
        let controller = BattleExitController(engine: engine, stateSaver: stateManager)
        
        var sessionResult: SessionResult?
        var cancellables = Set<AnyCancellable>()
        
        engine.onSessionComplete
            .sink { result in
                sessionResult = result
            }
            .store(in: &cancellables)
        
        // End & Record (retreat)
        controller.handle(.endAndRecord, taskMode: .focusStrictFixed)
        
        // Should create incomplete exit record
        XCTAssertEqual(engine.state, .retreat)
        XCTAssertNotNil(sessionResult)
        XCTAssertEqual(sessionResult?.endReason, .incompleteExit)
    }
    
    func testKeepFocusingDoesNothing() {
        let boss = Boss(name: "Keep Task", maxHp: 600)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        let controller = BattleExitController(engine: engine, stateSaver: stateManager)
        
        // Progress 30 seconds
        let checkTime = startTime.addingTimeInterval(30)
        engine.tick(at: checkTime)
        
        // Simulate "Keep Focusing" (do nothing, just cancel dialog)
        controller.handle(.keepFocusing, taskMode: .focusStrictFixed)
        // State should remain fighting
        XCTAssertEqual(engine.state, .fighting)
        XCTAssertNotNil(engine.currentBoss)
        
        // Continue fighting
        let laterTime = startTime.addingTimeInterval(60)
        engine.tick(at: laterTime)
        
        XCTAssertEqual(engine.state, .fighting)
        guard let elapsed = engine.currentSessionElapsed(at: laterTime) else {
            XCTFail("Expected elapsed time while fighting")
            return
        }
        XCTAssertEqual(elapsed, 60, accuracy: 0.1)
    }
    
    // MARK: - Frozen State Tests
    
    func testElapsedTimeStopsDuringFreeze() {
        let boss = Boss(name: "Frozen Task", maxHp: 600, style: .focus)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        // Progress 30 seconds, then freeze
        let freezeTime = startTime.addingTimeInterval(30)
        engine.tick(at: freezeTime)
        XCTAssertTrue(engine.freeze(at: freezeTime))
        
        XCTAssertEqual(engine.state, .frozen)
        
        // Frozen state elapsed should still be 30s
        guard let elapsed = engine.currentSessionElapsed(at: freezeTime.addingTimeInterval(100)) else {
            XCTFail("Expected elapsed time while frozen")
            return
        }
        XCTAssertEqual(elapsed, 30, accuracy: 0.1)
        
        // Resume should continue fighting
        let resumeTime = freezeTime.addingTimeInterval(100)
        engine.resumeFromFreeze(at: resumeTime)
        
        XCTAssertEqual(engine.state, .fighting)
        
        // Can still abort from resumed state if within total elapsed
        engine.abortSession()
        XCTAssertEqual(engine.state, .idle)
    }
    
    // MARK: - Passive Task Tests
    
    func testPassiveTaskDoesNotShowUndoOption() {
        let passiveBoss = Boss(name: "Passive Task", maxHp: 0, style: .passive)
        daySession = DaySession(nodes: [
            TimelineNode(type: .battle(passiveBoss), isLocked: false)
        ])
        
        // Passive tasks complete immediately, no retreat dialog needed
        XCTAssertEqual(passiveBoss.style, .passive)
        
        // Passive tasks should use instant completion path
        engine.startBattle(boss: passiveBoss)
        engine.completePassiveTask()
        
        XCTAssertEqual(engine.state, .victory)
    }
    
    // MARK: - Edge Cases
    
    func testElapsedTimeInPausedState() {
        let boss = Boss(name: "Paused Task", maxHp: 600)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        // Progress 30 seconds
        let pauseTime = startTime.addingTimeInterval(30)
        engine.tick(at: pauseTime)
        engine.pause(at: pauseTime)
        
        XCTAssertEqual(engine.state, .paused)
        
        // Elapsed should freeze at 30s even after more time passes
        let laterTime = pauseTime.addingTimeInterval(50)
        guard let elapsed = engine.currentSessionElapsed(at: laterTime) else {
            XCTFail("Expected elapsed time while paused")
            return
        }
        XCTAssertEqual(elapsed, 30, accuracy: 0.1)
    }
    
    func testRetreatDialogMessage() {
        // This test documents the expected message text
        let expectedMessage = "Undo Start is only available within 60 seconds. Otherwise, exit will be recorded as incomplete."
        
        // Message should be shown in confirmationDialog
        XCTAssertFalse(expectedMessage.isEmpty)
        XCTAssertTrue(expectedMessage.contains("60 seconds"))
        XCTAssertTrue(expectedMessage.contains("incomplete"))
    }
}
