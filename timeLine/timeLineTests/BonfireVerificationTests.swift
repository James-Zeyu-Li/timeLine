import XCTest
import Combine
@testable import timeLine

@MainActor
final class BonfireVerificationTests: XCTestCase {
    
    var coordinator: TimelineEventCoordinator!
    var engine: BattleEngine!
    var daySession: DaySession!
    var stateManager: MockStateSaver!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        engine = BattleEngine()
        daySession = DaySession(nodes: []) // Empty initially
        stateManager = MockStateSaver()
        coordinator = TimelineEventCoordinator(engine: engine, daySession: daySession, stateManager: stateManager)
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        coordinator = nil
        stateManager = nil
        daySession = nil
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Use Case 3: Bonfire Suggestion
    
    func testBonfireSuggestion_TriggerByBattles() {
        // Setup: 2 Battles then a Bonfire downstream
        let boss1 = Boss(name: "Boss 1", maxHp: 60)
        let boss2 = Boss(name: "Boss 2", maxHp: 60)
        let bonfire = TimelineNode(type: .bonfire(900), isLocked: false)
        
        daySession.nodes = [
            TimelineNode(type: .battle(boss1), isLocked: false),
            TimelineNode(type: .battle(boss2), isLocked: false),
            bonfire
        ]
        
        // Expectation: Suggestion should fire after 2nd victory
        let expectation = XCTestExpectation(description: "Bonfire Suggested due to consecutive battles")
        
        coordinator.uiEvents.sink { event in
            if case .bonfireSuggested(let reason, let id) = event {
                XCTAssertTrue(reason.contains("连续战斗"))
                XCTAssertEqual(id, bonfire.id)
                expectation.fulfill()
            }
        }.store(in: &cancellables)
        
        // Act: Win 2 battles
        // 1. Win Boss 1
        daySession.setCurrentNode(id: daySession.nodes[0].id)
        engine.startBattle(boss: boss1)
        engine.forceCompleteTask() // Triggers session complete -> Coordinator advances
        
        // 2. Win Boss 2
        // Simulate next battle start
        if let nextNode = daySession.currentNode, case .battle(let b2) = nextNode.type {
            engine.startBattle(boss: b2)
            engine.forceCompleteTask() // 2nd win
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testBonfireSuggestion_TriggerByFocusTime() {
        // Setup: 1 Long Battle (45m+) then a Bonfire
        let longBoss = Boss(name: "Long Task", maxHp: 45 * 60)
        let bonfire = TimelineNode(type: .bonfire(900), isLocked: false)
        
        daySession.nodes = [
            TimelineNode(type: .battle(longBoss), isLocked: false),
            bonfire
        ]
        
        let expectation = XCTestExpectation(description: "Bonfire Suggested due to focus time")
        
        coordinator.uiEvents.sink { event in
            if case .bonfireSuggested(let reason, let id) = event {
                XCTAssertTrue(reason.contains("专注时间"))
                XCTAssertEqual(id, bonfire.id)
                expectation.fulfill()
            }
        }.store(in: &cancellables)
        
        // Act: Win long battle
        daySession.setCurrentNode(id: daySession.nodes[0].id)
        engine.startBattle(boss: longBoss)
        engine.forceCompleteTask()
        
        wait(for: [expectation], timeout: 1.0)
    }
}
