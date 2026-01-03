import XCTest
@testable import TimeLineCore

final class TaskBehaviorTests: XCTestCase {
    func testBehaviorUsesRemindAt() {
        let remindAt = Date().addingTimeInterval(300)
        let boss = Boss(name: "Reminder", maxHp: 60, remindAt: remindAt)
        let node = TimelineNode(type: .battle(boss), isLocked: false)
        let behavior = node.effectiveTaskBehavior { _ in nil }
        XCTAssertEqual(behavior, .reminder)
    }

    func testBehaviorUsesPassiveStyle() {
        let boss = Boss(name: "Passive", maxHp: 60, style: .passive)
        let node = TimelineNode(type: .battle(boss), isLocked: false)
        let behavior = node.effectiveTaskBehavior { _ in nil }
        XCTAssertEqual(behavior, .reminder)
    }

    func testBehaviorUsesTemplateReminderMode() {
        let templateId = UUID()
        let template = CardTemplate(id: templateId, title: "Reminder", taskMode: .reminderOnly)
        let boss = Boss(name: "Task", maxHp: 60, templateId: templateId)
        let node = TimelineNode(type: .battle(boss), isLocked: false)
        let behavior = node.effectiveTaskBehavior { id in
            id == templateId ? template : nil
        }
        XCTAssertEqual(behavior, .reminder)
    }

    func testBehaviorDefaultsToBattle() {
        let boss = Boss(name: "Focus", maxHp: 60)
        let node = TimelineNode(type: .battle(boss), isLocked: false)
        let behavior = node.effectiveTaskBehavior { _ in nil }
        XCTAssertEqual(behavior, .battle)
    }
}
