import XCTest
@testable import TimeLineCore

final class ReminderSchedulerTests: XCTestCase {
    func testReminderTriggersAtLeadTime() {
        let now = Date()
        let remindAt = now.addingTimeInterval(600)
        let boss = Boss(
            name: "Reminder Task",
            maxHp: 60,
            remindAt: remindAt,
            leadTimeMinutes: 5
        )
        let node = TimelineNode(type: .battle(boss), isLocked: false)
        let scheduler = ReminderScheduler()

        let early = scheduler.evaluate(nodes: [node], at: now.addingTimeInterval(200))
        XCTAssertTrue(early.isEmpty)

        let triggered = scheduler.evaluate(nodes: [node], at: now.addingTimeInterval(300))
        XCTAssertEqual(triggered.count, 1)
        XCTAssertEqual(triggered.first?.nodeId, node.id)
        XCTAssertEqual(triggered.first?.leadTimeMinutes, 5)
        XCTAssertEqual(triggered.first?.isOverdue, false)
    }

    func testReminderDoesNotRepeat() {
        let now = Date()
        let remindAt = now.addingTimeInterval(60)
        let boss = Boss(
            name: "Reminder Task",
            maxHp: 60,
            remindAt: remindAt,
            leadTimeMinutes: 1
        )
        let node = TimelineNode(type: .battle(boss), isLocked: false)
        let scheduler = ReminderScheduler()

        let first = scheduler.evaluate(nodes: [node], at: now)
        XCTAssertEqual(first.count, 1)

        let second = scheduler.evaluate(nodes: [node], at: now.addingTimeInterval(120))
        XCTAssertTrue(second.isEmpty)
    }

    func testCompletedNodesAreIgnored() {
        let now = Date()
        let remindAt = now.addingTimeInterval(60)
        let boss = Boss(
            name: "Completed Task",
            maxHp: 60,
            remindAt: remindAt,
            leadTimeMinutes: 1
        )
        let node = TimelineNode(type: .battle(boss), isCompleted: true, isLocked: false)
        let scheduler = ReminderScheduler()

        let events = scheduler.evaluate(nodes: [node], at: now)
        XCTAssertTrue(events.isEmpty)
    }
}
