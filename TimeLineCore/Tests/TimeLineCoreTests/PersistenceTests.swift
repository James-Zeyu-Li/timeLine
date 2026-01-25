import XCTest
@testable import TimeLineCore

@MainActor
final class PersistenceTests: XCTestCase {
    
    // MARK: - Round Trip Tests
    
    func testAppStateRoundTrip() throws {
        // 1. Setup Data
        let boss = Boss(name: "Test Boss", maxHp: 300)
        let nodes = [TimelineNode(type: .battle(boss), isLocked: false)]
        let session = DaySession(nodes: nodes)
        let engineState = BattleSnapshot(
            boss: boss,
            state: .fighting,
            startTime: Date(),
            elapsedBeforeLastSave: 0,
            wastedTime: 50,
            isImmune: false,
            immunityCount: 0,
            distractionStartTime: nil,
            totalFocusedHistoryToday: 100,
            history: nil
        )
        
        // 2. Create AppState
        let originalState = AppState(
            lastSeenAt: Date(),
            daySession: session,
            engineState: engineState,
            history: [],
            spawnedKeys: ["test_key"]
        )
        
        // 3. Encode & Decode
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalState)
        let decodedState = try decoder.decode(AppState.self, from: data)
        
        // 4. Verify
        XCTAssertEqual(decodedState.daySession.nodes.count, 1)
        XCTAssertEqual(decodedState.engineState?.boss.name, "Test Boss")
        XCTAssertEqual(decodedState.engineState?.wastedTime, 50)
        XCTAssertTrue(decodedState.spawnedKeys.contains("test_key"))
    }

    // MARK: - Reconciliation Tests
    
    func testCrashReconciliation() {
        // Scenario: User starts battle at T=0. App crashes/killed at T=10. User reopens at T=30.
        // Expected: Gap of 20s (from 10 to 30) should be counted as Wasted Time.
        
        // 1. Setup Engine to T=0
        let clock = MasterClockService()
        let engine = BattleEngine(masterClock: clock)
        let boss = Boss(name: "Crash Boss", maxHp: 600)
        let startTime = Date()
        
        // Start battle
        engine.startBattle(boss: boss, at: startTime)
        
        // 2. Simulate Save at T=10 (Backgrounding or periodic save)
        let T10 = startTime.addingTimeInterval(10)
        // We need to manually advance state to T10 for the snapshot
        // In real app, update() is called by Timer.
        // We can mimic this by starting at T=0, and creating a snapshot that claims we are at T=10?
        // BattleEngine.start resets state.
        
        // Let's create a snapshot manually representing the state at T=10
        let snapshotAtT10 = BattleSnapshot(
            boss: boss,
            state: .fighting,
            startTime: startTime, // Started at 0
            elapsedBeforeLastSave: 0, // No previous chunks
            wastedTime: 0,
            isImmune: false,
            immunityCount: 0,
            distractionStartTime: nil,
            totalFocusedHistoryToday: 0,
            history: []
        )
        
        // 3. Restore at T=30 (Crash recovery)
        let T30 = startTime.addingTimeInterval(30)
        
        // We restore the snapshot taken at T=10 (conceptually), but actually snapshots usually happen just before kill?
        // If app is killed FORCEFULLY, the last save was at T=10 (e.g. backgrounded or debounced).
        // Then we reopen at T=30.
        // The lastSeenAt would be T=10 (when save happened).
        
        engine.restore(from: snapshotAtT10)
        engine.reconcile(lastSeenAt: T10, now: T30)
        
        // 4. Verify
        // Gap = 30 - 10 = 20s.
        // In Strict Mode, this 20s is Wasted Time.
        // The task timer should effectively resume from T=10? Or does it verify against real time?
        // reconcile logic:
        // gap = now - lastSeenAt
        // wastedTime += gap
        
        XCTAssertEqual(engine.wastedTime, 20, accuracy: 0.1, "Gap time should be recorded as wasted time")
        XCTAssertEqual(engine.state, .fighting, "Should resume running")
    }
    
    func testImmuneReconciliation() {
        // Scenario: Immunity enabled.
        // Gap should NOT be wasted time.
        
        let clock = MasterClockService()
        let engine = BattleEngine(masterClock: clock)
        let boss = Boss(name: "Immune Boss", maxHp: 600)
        let startTime = Date()
        
        let snapshot = BattleSnapshot(
            boss: boss,
            state: .fighting,
            startTime: startTime,
            elapsedBeforeLastSave: 0,
            wastedTime: 0,
            isImmune: true, // IMMUNE
            immunityCount: 0,
            distractionStartTime: nil,
            totalFocusedHistoryToday: 0,
            history: []
        )
        
        let T10 = startTime.addingTimeInterval(10)
        let T30 = startTime.addingTimeInterval(30)
        
        engine.restore(from: snapshot)
        engine.reconcile(lastSeenAt: T10, now: T30)
        
        XCTAssertEqual(engine.wastedTime, 0, "Immune session should not accumulate wasted time")
    }
}
