import XCTest
@testable import timeLine

@MainActor
final class TimelineStoreReorderTests: XCTestCase {
    
    func testMoveNodeUpdatesOrderAndCurrentIndex() async {
        let nodeA = TimelineNode(id: UUID(), type: .treasure, isLocked: false)
        let nodeB = TimelineNode(id: UUID(), type: .treasure, isLocked: false)
        let nodeC = TimelineNode(id: UUID(), type: .treasure, isLocked: false)
        let daySession = DaySession(nodes: [nodeA, nodeB, nodeC], currentIndex: 1)
        let engine = BattleEngine()
        let templateStore = TemplateStore()
        let cardStore = CardTemplateStore()
        let stateManager = AppStateManager(
            engine: engine,
            daySession: daySession,
            templateStore: templateStore,
            cardStore: cardStore
        )
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        
        timelineStore.moveNode(from: IndexSet(integer: 0), to: 3)
        
        XCTAssertEqual(daySession.nodes.map(\.id), [nodeB.id, nodeC.id, nodeA.id])
        XCTAssertEqual(daySession.currentIndex, 0)
    }
    
    func testMoveNodeUpdatesLockStates() async {
        let nodeA = TimelineNode(id: UUID(), type: .treasure, isLocked: true)
        let nodeB = TimelineNode(id: UUID(), type: .treasure, isLocked: true)
        let nodeC = TimelineNode(id: UUID(), type: .treasure, isCompleted: true, isLocked: true)
        let nodeD = TimelineNode(id: UUID(), type: .treasure, isLocked: true)
        let daySession = DaySession(nodes: [nodeA, nodeB, nodeC, nodeD], currentIndex: 1)
        let engine = BattleEngine()
        let templateStore = TemplateStore()
        let cardStore = CardTemplateStore()
        let stateManager = AppStateManager(
            engine: engine,
            daySession: daySession,
            templateStore: templateStore,
            cardStore: cardStore
        )
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        
        timelineStore.moveNode(from: IndexSet(integer: 3), to: 1)
        
        XCTAssertEqual(daySession.nodes.map(\.id), [nodeA.id, nodeD.id, nodeB.id, nodeC.id])
        XCTAssertFalse(daySession.nodes[0].isLocked)
        XCTAssertTrue(daySession.nodes[1].isLocked)
        XCTAssertFalse(daySession.nodes[2].isLocked)
        XCTAssertFalse(daySession.nodes[3].isLocked)
    }
    
    func testFinalizeReorderKeepsActiveNodeWhenSessionActive() async {
        let nodeA = TimelineNode(id: UUID(), type: .treasure, isLocked: false)
        let nodeB = TimelineNode(id: UUID(), type: .treasure, isLocked: false)
        let nodeC = TimelineNode(id: UUID(), type: .treasure, isLocked: false)
        let daySession = DaySession(nodes: [nodeA, nodeB, nodeC], currentIndex: 1)
        let engine = BattleEngine()
        let templateStore = TemplateStore()
        let cardStore = CardTemplateStore()
        let stateManager = AppStateManager(
            engine: engine,
            daySession: daySession,
            templateStore: templateStore,
            cardStore: cardStore
        )
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        
        timelineStore.moveNode(from: IndexSet(integer: 1), to: 3)
        timelineStore.finalizeReorder(isSessionActive: true, activeNodeId: nodeB.id)
        
        XCTAssertEqual(daySession.currentIndex, 2)
    }
    
    func testFinalizeReorderResetsCurrentIndexWhenSessionInactive() async {
        let nodeA = TimelineNode(id: UUID(), type: .treasure, isCompleted: true, isLocked: false)
        let nodeB = TimelineNode(id: UUID(), type: .treasure, isCompleted: true, isLocked: false)
        let nodeC = TimelineNode(id: UUID(), type: .treasure, isCompleted: false, isLocked: true)
        let nodeD = TimelineNode(id: UUID(), type: .treasure, isCompleted: false, isLocked: true)
        let daySession = DaySession(nodes: [nodeA, nodeB, nodeC, nodeD], currentIndex: 0)
        let engine = BattleEngine()
        let templateStore = TemplateStore()
        let cardStore = CardTemplateStore()
        let stateManager = AppStateManager(
            engine: engine,
            daySession: daySession,
            templateStore: templateStore,
            cardStore: cardStore
        )
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        
        timelineStore.finalizeReorder(isSessionActive: false, activeNodeId: nil)
        
        XCTAssertEqual(daySession.currentIndex, 2)
        XCTAssertFalse(daySession.nodes[0].isLocked)
        XCTAssertFalse(daySession.nodes[2].isLocked)
        XCTAssertTrue(daySession.nodes[3].isLocked)
    }
}
