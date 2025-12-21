import XCTest
@testable import TimeLineCore

final class BattleEngineTests: XCTestCase {
    
    var engine: BattleEngine!
    
    override func setUp() {
        super.setUp()
        engine = BattleEngine()
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
    
    func testForceCompleteTask() {
        let boss = Boss(name: "Debug Boss", maxHp: 3600)
        engine.startBattle(boss: boss)
        
        engine.forceCompleteTask()
        
        XCTAssertEqual(engine.state, .victory)
        XCTAssertNil(engine.currentBoss)
        // Should have credited full duration (3600)
        XCTAssertEqual(engine.totalFocusedToday, 3600)
    }
}
