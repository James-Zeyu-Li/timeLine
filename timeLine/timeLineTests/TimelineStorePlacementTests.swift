import XCTest
@testable import timeLine

@MainActor
final class TimelineStorePlacementTests: XCTestCase {
    
    func testPlaceCreatesNewNodeFromTemplate() {
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
    
    func testPlaceTaskTemplateOccurrenceAppendsAndSaves() {
        let daySession = DaySession(nodes: [])
        let stateManager = MockStateSaver()
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        let engine = BattleEngine()
        
        let template = TaskTemplate(title: "Inbox Task", duration: 600)
        let newNodeId = timelineStore.placeTaskTemplateOccurrenceAtEnd(template, engine: engine)
        
        XCTAssertEqual(daySession.nodes.count, 1)
        XCTAssertEqual(daySession.nodes[0].id, newNodeId)
        XCTAssertFalse(daySession.nodes[0].isLocked)
        XCTAssertEqual(daySession.currentIndex, 0)
        
        guard case .battle(let boss) = daySession.nodes[0].type else {
            XCTFail("Expected inserted node to be battle")
            return
        }
        
        XCTAssertEqual(boss.name, template.title)
        XCTAssertEqual(boss.maxHp, 600)
        XCTAssertEqual(boss.templateId, template.id)
        XCTAssertTrue(stateManager.saveRequested)
    }
}
