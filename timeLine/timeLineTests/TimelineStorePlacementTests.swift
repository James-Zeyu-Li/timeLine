import XCTest
@testable import TimeLineCore
@testable import timeLine

@MainActor
final class TimelineStorePlacementTests: XCTestCase {
    
    func testPlaceCreatesNewNodeFromTemplate() {
        let daySession = DaySession(nodes: [
            TimelineNode(type: .treasure, isLocked: false)
        ])
        let engine = BattleEngine()
        let templateStore = TemplateStore()
        let stateManager = AppStateManager(engine: engine, daySession: daySession, templateStore: templateStore)
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
    }
}
