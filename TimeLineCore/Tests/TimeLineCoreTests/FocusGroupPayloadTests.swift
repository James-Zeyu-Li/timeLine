import XCTest
@testable import TimeLineCore

final class FocusGroupPayloadTests: XCTestCase {
    func testFocusGroupPayloadRoundTripOnTimelineNode() throws {
        let firstId = UUID()
        let secondId = UUID()
        let payload = FocusGroupPayload(memberTemplateIds: [firstId, secondId], activeIndex: 1)
        let boss = Boss(name: "Focus Group", maxHp: 1200, focusGroupPayload: payload)
        let node = TimelineNode(
            type: .battle(boss),
            isLocked: true,
            taskModeOverride: .focusGroupFlexible
        )
        
        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(TimelineNode.self, from: data)
        
        guard case .battle(let decodedBoss) = decoded.type else {
            XCTFail("Expected decoded node to be battle")
            return
        }
        
        XCTAssertEqual(decodedBoss.focusGroupPayload, payload)
        XCTAssertEqual(decoded.taskModeOverride, .focusGroupFlexible)
    }
}
