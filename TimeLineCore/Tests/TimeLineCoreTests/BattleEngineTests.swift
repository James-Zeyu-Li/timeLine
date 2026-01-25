import XCTest
import Combine
@testable import TimeLineCore

@MainActor
final class BattleEngineTests: XCTestCase {
    
    var engine: BattleEngine!
    
    override func setUp() {
        super.setUp()
        let clock = MasterClockService()
        engine = BattleEngine(masterClock: clock)
    }
    
    func testStartBattle() {
        let boss = Boss(name: "Test Boss", maxHp: 60)
        engine.startBattle(boss: boss)
        
        XCTAssertEqual(engine.state, .fighting)
        XCTAssertEqual(engine.currentBoss?.name, "Test Boss")
        XCTAssertEqual(engine.currentBoss?.currentHp, 60)
    }
    
    func testTickDecreasesHp() {
        let boss = Boss(name: "Test Boss", maxHp: 60)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        // Simulate 10 seconds passing
        let tenSecondsLater = startTime.addingTimeInterval(10)
        engine.tick(at: tenSecondsLater)
        
        XCTAssertEqual(engine.currentBoss!.currentHp, 50, accuracy: 0.1)
    }
    
    func testVictoryCondition() {
        let boss = Boss(name: "Weak Boss", maxHp: 10)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        // Simulate 11 seconds passing (victory)
        let elevenSecondsLater = startTime.addingTimeInterval(11)
        engine.tick(at: elevenSecondsLater)
        
        XCTAssertEqual(engine.state, .victory)
        XCTAssertNil(engine.currentBoss)
    }
    
    func testPauseResume() {
        let boss = Boss(name: "Long Boss", maxHp: 100)
        let startTime = Date()
        
        // Start
        engine.startBattle(boss: boss, at: startTime)
        
        // Fight for 10s
        let pauseTime = startTime.addingTimeInterval(10)
        engine.tick(at: pauseTime)
        XCTAssertEqual(engine.currentBoss!.currentHp, 90, accuracy: 0.1)
        
        // Pause
        engine.pause(at: pauseTime)
        XCTAssertEqual(engine.state, .paused)
        
        // Wait 20s while paused (simulated)
        let resumeTime = pauseTime.addingTimeInterval(20)
        
        // Resume
        engine.resume(at: resumeTime)
        XCTAssertEqual(engine.state, .fighting)
        
        // Tick immediately after resume (should still be at 90)
        engine.tick(at: resumeTime)
        XCTAssertEqual(engine.currentBoss!.currentHp, 90, accuracy: 0.1)
        
        // Tick 10s after resume (total active time = 20s)
        let checkTime = resumeTime.addingTimeInterval(10)
        engine.tick(at: checkTime)
        XCTAssertEqual(engine.currentBoss!.currentHp, 80, accuracy: 0.1)
    }
    
    func testRetreat() {
        let boss = Boss(name: "Boss", maxHp: 60)
        engine.startBattle(boss: boss)
        engine.retreat()
        XCTAssertEqual(engine.state, .retreat)
    }
    
    func testRetreatEmitsIncompleteExit() {
        let boss = Boss(name: "Boss", maxHp: 60)
        let startTime = Date()
        let expectation = XCTestExpectation(description: "Incomplete exit emits session result")
        var received: SessionResult?
        var cancellables = Set<AnyCancellable>()
        
        engine.onSessionComplete
            .sink { result in
                received = result
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        engine.startBattle(boss: boss, at: startTime)
        let retreatTime = startTime.addingTimeInterval(10)
        engine.tick(at: retreatTime)
        engine.retreat(at: retreatTime)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(received?.endReason, .incompleteExit)
        XCTAssertNotNil(received?.remainingSecondsAtExit)
    }
    
    func testForceCompleteTask() {
        let boss = Boss(name: "Debug Boss", maxHp: 3600)
        engine.startBattle(boss: boss)
        
        engine.forceCompleteTask()
        
        XCTAssertEqual(engine.state, .victory)
        XCTAssertNil(engine.currentBoss)
        // Should have credited full duration (3600)
        XCTAssertEqual(engine.totalFocusedToday, 3600)
    }

    func testFreezeRecordsDurationAndConsumesToken() {
        let boss = Boss(name: "Freeze Boss", maxHp: 600)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        let freezeTime = startTime.addingTimeInterval(120)
        engine.tick(at: freezeTime)
        
        XCTAssertTrue(engine.freeze(at: freezeTime))
        XCTAssertEqual(engine.state, .frozen)
        XCTAssertEqual(engine.freezeTokensUsed, 1)
        XCTAssertEqual(engine.freezeTokensRemaining, 2)
        
        let resumeTime = freezeTime.addingTimeInterval(90)
        engine.resumeFromFreeze(at: resumeTime)
        
        XCTAssertEqual(engine.state, .fighting)
        XCTAssertEqual(engine.freezeHistory.count, 1)
        let record = engine.freezeHistory[0]
        XCTAssertEqual(record.bossName, "Freeze Boss")
        XCTAssertEqual(record.duration, 90, accuracy: 0.1)
    }
    
    // MARK: - Grace Exit Tests
    
    func testAbortSessionWithinGracePeriod() {
        let boss = Boss(name: "Grace Task", maxHp: 600)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        // Within grace period (≤60s)
        let abortTime = startTime.addingTimeInterval(30)
        engine.tick(at: abortTime)
        
        let elapsed = engine.currentSessionElapsed(at: abortTime)
        XCTAssertNotNil(elapsed)
        XCTAssertEqual(elapsed!, 30, accuracy: 0.1)
        XCTAssertEqual(engine.state, .fighting)
        
        // Abort session
        engine.abortSession()
        
        // Should return to idle without recording
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.currentBoss)
        XCTAssertEqual(engine.totalFocusedToday, 0) // No credit
    }
    
    func testAbortSessionAfterGracePeriodStillWorks() {
        let boss = Boss(name: "Late Abort Task", maxHp: 600)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        // After grace period (>60s)
        let abortTime = startTime.addingTimeInterval(120)
        engine.tick(at: abortTime)
        
        let elapsed = engine.currentSessionElapsed(at: abortTime)
        XCTAssertNotNil(elapsed)
        XCTAssertEqual(elapsed!, 120, accuracy: 0.1)
        
        // Abort still works (no recording)
        engine.abortSession()
        
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.currentBoss)
        XCTAssertEqual(engine.totalFocusedToday, 0)
    }
    
    func testCurrentSessionElapsedWithinGrace() {
        let boss = Boss(name: "Elapsed Task", maxHp: 600)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        let checkTime30s = startTime.addingTimeInterval(30)
        engine.tick(at: checkTime30s)
        let elapsed30 = engine.currentSessionElapsed(at: checkTime30s)
        XCTAssertNotNil(elapsed30)
        XCTAssertEqual(elapsed30!, 30, accuracy: 0.1)
        
        let checkTime60s = startTime.addingTimeInterval(60)
        engine.tick(at: checkTime60s)
        let elapsed60 = engine.currentSessionElapsed(at: checkTime60s)
        XCTAssertNotNil(elapsed60)
        XCTAssertEqual(elapsed60!, 60, accuracy: 0.1)
        
        let checkTime61s = startTime.addingTimeInterval(61)
        engine.tick(at: checkTime61s)
        let elapsed61 = engine.currentSessionElapsed(at: checkTime61s)
        XCTAssertNotNil(elapsed61)
        XCTAssertEqual(elapsed61!, 61, accuracy: 0.1)
    }

    
    func testAbortSessionResetsAllState() {
        let boss = Boss(name: "Reset Task", maxHp: 600)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        // Accumulate wasted time (without immunity)
        engine.handleBackgrounding(at: startTime.addingTimeInterval(10))
        engine.handleForegrounding(at: startTime.addingTimeInterval(20))
        
        XCTAssertTrue(engine.wastedTime > 0)
        
        // Grant immunity to test it gets reset
        engine.grantImmunity()
        XCTAssertTrue(engine.isImmune)
        XCTAssertEqual(engine.immunityCount, 0)
        
        // Abort should reset everything
        engine.abortSession()
        
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.currentBoss)
        XCTAssertEqual(engine.wastedTime, 0)
        XCTAssertFalse(engine.isImmune)
        XCTAssertEqual(engine.immunityCount, 1)
    }
    
    func testBirdScareGracePeriod() {
        let boss = Boss(name: "Bird Task", maxHp: 600)
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        
        // 1. Short distraction (Within 10s grace)
        // Background at T+10
        let bgTime1 = startTime.addingTimeInterval(10)
        engine.handleBackgrounding(at: bgTime1)
        
        // Foreground at T+15 (Duration 5s)
        let fgTime1 = startTime.addingTimeInterval(15)
        engine.handleForegrounding(at: fgTime1)
        
        // Should be ignored
        XCTAssertEqual(engine.wastedTime, 0, "Grace period should prevent wasted time for short distractions")
        
        // 2. Long distraction (Exceeds 10s grace)
        // Background at T+20
        let bgTime2 = startTime.addingTimeInterval(20)
        engine.handleBackgrounding(at: bgTime2)
        
        // Foreground at T+35 (Duration 15s)
        let fgTime2 = startTime.addingTimeInterval(35)
        engine.handleForegrounding(at: fgTime2)
        
        // Should be penalized
        XCTAssertEqual(engine.wastedTime, 15, accuracy: 0.1, "Exceeding grace period should add to wasted time")
    }
}
