import XCTest
@testable import TimeLineCore

final class RoutineLogicTests: XCTestCase {

    // Test 1: Append into Empty Session
    func testAppendIntoEmptySession() {
        // Setup
        let session = DaySession(nodes: [])
        let template = RoutineTemplate(name: "Test Flow", presets: [
            BossPreset(title: "Task 1", duration: 1800, style: .focus),
            BossPreset(title: "Task 2", duration: 1800, style: .focus),
            BossPreset(title: "Task 3", duration: 1800, style: .focus)
        ])
        
        // Action
        session.appendRoutine(template)
        
        // Assertions
        // RouteGenerator logic: Task 1 -> Task 2 -> Bonfire -> Task 3
        XCTAssertEqual(session.nodes.count, 4, "Should have 4 nodes (3 Tasks + 1 Auto-Bonfire)")
        
        // Check Types
        if case .battle = session.nodes[0].type {} else { XCTFail("Node 0 should be Battle") }
        if case .battle = session.nodes[1].type {} else { XCTFail("Node 1 should be Battle") }
        if case .bonfire = session.nodes[2].type {} else { XCTFail("Node 2 should be Bonfire") }
        if case .battle = session.nodes[3].type {} else { XCTFail("Node 3 should be Battle") }
        
        // Check Activation
        XCTAssertFalse(session.nodes[0].isLocked, "Node 0 should be UNLOCKED (Active)")
        XCTAssertTrue(session.nodes[1].isLocked, "Node 1 should be LOCKED")
        XCTAssertTrue(session.nodes[2].isLocked, "Node 2 (Bonfire) should be LOCKED")
    }

    // Test 2: Append while Mid-Run
    func testAppendMidRun() {
        // Setup: A session with one active task
        let boss = Boss(name: "Existing", maxHp: 60)
        let existingNode = TimelineNode(type: .battle(boss), isLocked: false)
        let session = DaySession(nodes: [existingNode])
        
        let template = RoutineTemplate(name: "Add-on", presets: [
            BossPreset(title: "New Task", duration: 60)
        ])
        
        // Action
        session.appendRoutine(template)
        
        // Assertions
        XCTAssertEqual(session.nodes.count, 2, "Should have 2 nodes total")
        XCTAssertEqual(session.currentIndex, 0, "Current index should stay at 0")
        
        // Check Activation of NEW node
        XCTAssertTrue(session.nodes[1].isLocked, "New appended node should be LOCKED because session is mid-run")
    }
}
