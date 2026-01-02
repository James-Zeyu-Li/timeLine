import XCTest
@testable import timeLine

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
}
