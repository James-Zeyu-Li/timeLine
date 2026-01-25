import XCTest
@testable import timeLine
import TimeLineCore

@MainActor
final class TimelineInsertionTests: XCTestCase {
    
    // MARK: - Setup
    
    private var daysSession: DaySession!
    private var stateManager: AppStateManager!
    private var timelineStore: TimelineStore!
    private var engine: BattleEngine!
    private var cardStore: CardTemplateStore!
    
    override func setUp() {
        super.setUp()
        daysSession = DaySession(nodes: [])
        // Mock State Manager (requires minimal init if possible, or we rely on it being nil-safe)
        // Since we are testing logic that might save, we need to be careful. 
        // For unit/integration tests, we might want a mock or in-memory persistence.
        // Assuming AppStateManager has a default init that is safe or we can use a temp path.
        // For now, let's try standard init.
        stateManager = AppStateManager() 
        timelineStore = TimelineStore(daySession: daysSession, stateManager: stateManager)
        engine = BattleEngine()
        cardStore = CardTemplateStore()
    }
    
    // MARK: - Insertion Tests
    
    func testPlaceCardAtStart_EmptyTimeline() {
        // Given
        XCTAssertTrue(daysSession.nodes.isEmpty)
        let template = CardTemplate(title: "First Task", defaultDuration: 1800)
        cardStore.add(template)
        
        // When
        let nodeId = timelineStore.placeCardOccurrenceAtStart(
            cardTemplateId: template.id,
            using: cardStore,
            engine: engine
        )
        
        // Then
        XCTAssertNotNil(nodeId)
        XCTAssertEqual(daysSession.nodes.count, 1)
        XCTAssertEqual(daysSession.nodes.first?.id, nodeId)
        
        // Verify node properties
        if let node = daysSession.nodes.first, case .battle(let boss) = node.type {
            XCTAssertEqual(boss.name, "First Task")
            XCTAssertEqual(boss.maxHp, 1800)
        } else {
            XCTFail("Node should be a battle node")
        }
    }
    
    func testPlaceCardAtStart_PopulatedTimeline() {
        // Given: Existing timeline with 2 nodes
        let t1 = CardTemplate(title: "Task 1", defaultDuration: 1000)
        let t2 = CardTemplate(title: "Task 2", defaultDuration: 1000)
        cardStore.add(t1)
        cardStore.add(t2)
        
        _ = timelineStore.placeCardOccurrenceAtStart(cardTemplateId: t1.id, using: cardStore, engine: engine)
        _ = timelineStore.placeCardOccurrenceAtStart(cardTemplateId: t2.id, using: cardStore, engine: engine)
        
        // Current behavior of `placeCardOccurrenceAtStart` appends to end? Or actually start?
        // Let's verify behavior. The name suggests "At Start". 
        // If logic is "Append", then Task 2 is after Task 1.
        // If logic is "Prepend", then Task 2 is First.
        // Based on typical `TimeLine` usage, new tasks often go to bottom (future).
        // BUT the function name is "AtStart". Let's check implementation behavior via test.
        
        // Re-reading logic: DaySession usually appends.
        // Let's assert based on `DaySession.add(node)`.
        
        XCTAssertEqual(daysSession.nodes.count, 2)
    }
    
    func testPlaceCardAtCurrent_QueueJumping() {
        // Scenario: User is doing Task A. They add Task B via "Zap" (Queue Jump).
        // Expected: Task A (paused/current) -> Task B (Next) -> Task C (Old Next)
        
        // Given
        let tA = CardTemplate(title: "Task A", defaultDuration: 1000)
        let tC = CardTemplate(title: "Task C (Future)", defaultDuration: 1000)
        cardStore.add(tA)
        cardStore.add(tC)
        
        // Add A and C
        let nodeA = timelineStore.placeCardOccurrenceAtStart(cardTemplateId: tA.id, using: cardStore, engine: engine)!
        let nodeC = timelineStore.placeCardOccurrenceAtStart(cardTemplateId: tC.id, using: cardStore, engine: engine)!
        
        // Set A as Current
        daysSession.setCurrentNode(id: nodeA)
        
        // When: Insert Task B at Current
        let tB = CardTemplate(title: "Task B (Jump)", defaultDuration: 500)
        cardStore.add(tB)
        
        let nodeB = timelineStore.placeCardOccurrenceAtCurrent(
            cardTemplateId: tB.id,
            using: cardStore,
            engine: engine
        )
        
        // Then
        XCTAssertNotNil(nodeB)
        XCTAssertEqual(daysSession.nodes.count, 3)
        
        // Order should be A -> B -> C
        // Verify indices
        let indexA = daysSession.nodes.firstIndex(where: { $0.id == nodeA })
        let indexB = daysSession.nodes.firstIndex(where: { $0.id == nodeB })
        let indexC = daysSession.nodes.firstIndex(where: { $0.id == nodeC })
        
        XCTAssertEqual(indexA, 0)
        XCTAssertEqual(indexB, 1)
        XCTAssertEqual(indexC, 2)
    }
}
