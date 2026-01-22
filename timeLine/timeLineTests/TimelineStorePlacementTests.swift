import XCTest
@testable import timeLine
import TimeLineCore

@MainActor
final class TimelineStorePlacementTests: XCTestCase {
    
    func testPlaceCreatesNewNodeFromTemplate() async {
        let daySession = DaySession(nodes: [
            TimelineNode(type: .treasure, isLocked: false)
        ])
        let stateManager = MockStateSaver()
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        
        let cardStore = CardTemplateStore()
        let template = CardTemplate(title: "Deep Work", defaultDuration: 1800)
        cardStore.add(template)
        
        let anchorId = daySession.nodes[0].id
        let newNodeId = timelineStore.placeCardOccurrence(
            cardTemplateId: template.id,
            anchorNodeId: anchorId,
            using: cardStore
        )
        XCTAssertNotNil(newNodeId)
        XCTAssertEqual(daySession.nodes.count, 2)
        
        guard case .battle(let boss) = daySession.nodes[1].type else {
            XCTFail("Expected inserted node to be battle")
            return
        }
        
        XCTAssertEqual(boss.name, template.title)
        XCTAssertEqual(boss.maxHp, template.defaultDuration)
        XCTAssertEqual(boss.templateId, template.id)
        XCTAssertTrue(stateManager.saveRequested)
    }
    
    func testPlaceCardOccurrenceAtStart_AppendsAndSaves() async {
        let daySession = DaySession(nodes: [])
        let stateManager = MockStateSaver()
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        let engine = BattleEngine()
        
        let cardStore = CardTemplateStore()
        let template = CardTemplate(title: "Inbox Task", defaultDuration: 600)
        cardStore.add(template)
        
        let newNodeId = timelineStore.placeCardOccurrenceAtStart(
            cardTemplateId: template.id,
            using: cardStore,
            engine: engine
        )
        
        XCTAssertNotNil(newNodeId)
        XCTAssertEqual(daySession.nodes.count, 1)
        XCTAssertEqual(daySession.nodes[0].id, newNodeId)
        XCTAssertFalse(daySession.nodes[0].isLocked)
        XCTAssertEqual(daySession.currentIndex, 0)
        
        guard case .battle(let boss) = daySession.nodes[0].type else {
            XCTFail("Expected inserted node to be battle")
            return
        }
        
        XCTAssertEqual(boss.name, template.title)
        XCTAssertEqual(boss.maxHp, template.defaultDuration)
        XCTAssertEqual(boss.templateId, template.id)
        XCTAssertTrue(stateManager.saveRequested)
    }
    
    func testPlaceFocusGroupOccurrence_InsertsNodeWithPayload() async {
        let daySession = DaySession(nodes: [
            TimelineNode(type: .treasure, isLocked: false)
        ])
        let stateManager = MockStateSaver()
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        
        let cardStore = CardTemplateStore()
        let first = CardTemplate(title: "Draft", defaultDuration: 900)
        let second = CardTemplate(title: "Review", defaultDuration: 600)
        cardStore.add(first)
        cardStore.add(second)
        
        let anchorId = daySession.nodes[0].id
        let newNodeId = timelineStore.placeFocusGroupOccurrence(
            memberTemplateIds: [first.id, second.id],
            anchorNodeId: anchorId,
            using: cardStore
        )
        
        XCTAssertNotNil(newNodeId)
        XCTAssertEqual(daySession.nodes.count, 2)
        XCTAssertEqual(daySession.nodes[1].taskModeOverride, .focusGroupFlexible)
        
        guard case .battle(let boss) = daySession.nodes[1].type else {
            XCTFail("Expected inserted node to be battle")
            return
        }
        
        XCTAssertNotNil(boss.focusGroupPayload)
        XCTAssertEqual(boss.focusGroupPayload?.memberTemplateIds, [first.id, second.id])
        XCTAssertEqual(boss.focusGroupPayload?.activeIndex, 0)
        XCTAssertEqual(boss.maxHp, 1500, accuracy: 0.1)
        XCTAssertTrue(stateManager.saveRequested)
    }

    func testPlaceCardOccurrenceByTime_InsertsAtCorrectPosition() async {
        // Setup: [Task A (30m)] -> [Task B (30m)]
        // Insert Task C at +45m from now. Should be between A and B.
        
        let engine = BattleEngine() // Use mock if needed, but real engine is fine for pure logic if simpler
        // Engine default state is idle.
        
        let cardStore = CardTemplateStore()
        let templateA = CardTemplate(title: "A", defaultDuration: 1800)
        let templateB = CardTemplate(title: "B", defaultDuration: 1800)
        let templateC = CardTemplate(title: "C", defaultDuration: 900) // Inserted
        
        cardStore.add(templateA)
        cardStore.add(templateB)
        cardStore.add(templateC)
        
        let bossA = Boss(id: UUID(), name: "A", maxHp: 1800, style: .focus, category: .work, templateId: templateA.id, recommendedStart: nil, remindAt: nil)
        let bossB = Boss(id: UUID(), name: "B", maxHp: 1800, style: .focus, category: .work, templateId: templateB.id, recommendedStart: nil, remindAt: nil)
        
        let nodeA = TimelineNode(type: .battle(bossA), isLocked: false)
        let nodeB = TimelineNode(type: .battle(bossB), isLocked: true)
        
        let daySession = DaySession(nodes: [nodeA, nodeB])
        let stateManager = MockStateSaver()
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        
        // C remindAt = Now + 45 min
        // A ends at +30m. B ends at +60m.
        // C should be inserted AFTER A (starts at +30m) but BEFORE B?
        // Wait, timeline is valid if previous tasks push subsequent ones.
        // Insert logic `reminderInsertIndex`: finds first task that starts at or AFTER `remindAt`.
        // A starts +0. B starts +30.
        // If remindAt = +45.
        // Loop:
        // Index 0 (Node A): starts +0. < 45.
        // Index 1 (Node B): starts +30. < 45. 
        // Wait, logic is `secondsAhead` accumulator.
        // Start: 0.
        // Check A (Index 0). Start 0.
        // Update secondsAhead += 30m. Next start: 30m.
        // Check B (Index 1). Start 30m.
        // Update secondsAhead += 30m. Next start: 60m.
        
        // If remindAt is 45m.
        // Logic: `if startDate >= remindAt`.
        
        // Iteration 0 (A): startDate 0. 0 >= 45 False.
        // Iteration 1 (B): startDate 30. 30 >= 45 False.
        // End of loop. Returns `allNodes.count` (2).
        // Result: A, B, C.
        // C starts at 60m. 60m >= 45m OK.
        
        // If remindAt is 10m.
        // Iteration 0 (A): startDate 0. 0 >= 10 False.
        // Iteration 1 (B): startDate 30. 30 >= 10 True!
        // Returns index of B (1).
        // Result: A, C, B.
        
        // Test case: Insert at +10m (Before B).
        let now = Date()
        let remindAt = now.addingTimeInterval(10 * 60) // +10m
        
        let newNodeId = timelineStore.placeCardOccurrenceByTime(
            cardTemplateId: templateC.id,
            remindAt: remindAt,
            using: cardStore,
            engine: engine
        )
        
        XCTAssertNotNil(newNodeId)
        XCTAssertEqual(daySession.nodes.count, 3)
        // Expected order: A, C, B
        XCTAssertEqual(daySession.nodes[0].id, nodeA.id)
        XCTAssertEqual(daySession.nodes[1].id, newNodeId)
        XCTAssertEqual(daySession.nodes[2].id, nodeB.id)
    }
}
