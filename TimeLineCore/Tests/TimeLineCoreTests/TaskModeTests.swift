import XCTest
@testable import TimeLineCore

final class TaskModeTests: XCTestCase {
    func testLegacyCardTemplateDecodeDefaultsTaskMode() throws {
        let id = UUID()
        let legacy: [String: Any] = [
            "id": id.uuidString,
            "title": "Legacy Task",
            "icon": "bolt.fill",
            "defaultDuration": 1500,
            "tags": [],
            "energyColor": "focus",
            "category": "work",
            "style": "focus"
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy, options: [])
        let decoded = try JSONDecoder().decode(CardTemplate.self, from: data)
        XCTAssertEqual(decoded.taskMode, .focusStrictFixed)
        XCTAssertEqual(decoded.repeatRule, .none)
    }
    
    func testEffectiveTaskModeUsesOverride() {
        let templateId = UUID()
        let template = CardTemplate(
            id: templateId,
            title: "Template",
            taskMode: .focusStrictFixed
        )
        let boss = Boss(
            name: "Occurrence",
            maxHp: 900,
            templateId: templateId
        )
        let node = TimelineNode(
            type: .battle(boss),
            isLocked: false,
            taskModeOverride: .reminderOnly
        )
        let effective = node.effectiveTaskMode { id in
            id == templateId ? template : nil
        }
        XCTAssertEqual(effective, .reminderOnly)
    }
    
    func testCardTemplateRoundTripPersistsTaskMode() throws {
        let original = CardTemplate(
            title: "Reminder",
            taskMode: .reminderOnly
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CardTemplate.self, from: data)
        XCTAssertEqual(decoded.taskMode, .reminderOnly)
    }

    func testTimelineNodeDecodeDefaultsTaskModeOverrideNil() throws {
        let boss = Boss(name: "Node", maxHp: 600)
        let node = TimelineNode(type: .battle(boss), isLocked: false, taskModeOverride: nil)
        let data = try JSONEncoder().encode(node)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        var stripped = jsonObject ?? [:]
        stripped.removeValue(forKey: "taskModeOverride")
        let strippedData = try JSONSerialization.data(withJSONObject: stripped, options: [])
        let decoded = try JSONDecoder().decode(TimelineNode.self, from: strippedData)
        XCTAssertNil(decoded.taskModeOverride)
    }
}
