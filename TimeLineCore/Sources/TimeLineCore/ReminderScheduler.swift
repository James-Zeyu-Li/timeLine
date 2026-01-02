import Foundation

public struct ReminderEvent: Equatable {
    public let nodeId: UUID
    public let taskName: String
    public let remindAt: Date
    public let leadTimeMinutes: Int
    public let remainingSeconds: TimeInterval
    public let isOverdue: Bool

    public init(
        nodeId: UUID,
        taskName: String,
        remindAt: Date,
        leadTimeMinutes: Int,
        remainingSeconds: TimeInterval,
        isOverdue: Bool
    ) {
        self.nodeId = nodeId
        self.taskName = taskName
        self.remindAt = remindAt
        self.leadTimeMinutes = leadTimeMinutes
        self.remainingSeconds = remainingSeconds
        self.isOverdue = isOverdue
    }
}

public final class ReminderScheduler {
    private var firedReminders: [UUID: Date] = [:]

    public init() {}

    @discardableResult
    public func evaluate(nodes: [TimelineNode], at date: Date = Date()) -> [ReminderEvent] {
        var events: [ReminderEvent] = []
        for node in nodes {
            guard !node.isCompleted else { continue }
            guard case .battle(let boss) = node.type else { continue }
            guard let remindAt = boss.remindAt else { continue }

            let leadMinutes = max(0, boss.leadTimeMinutes)
            let triggerAt = remindAt.addingTimeInterval(TimeInterval(-leadMinutes * 60))
            guard date >= triggerAt else { continue }

            if let firedAt = firedReminders[node.id], firedAt == remindAt {
                continue
            }
            firedReminders[node.id] = remindAt

            let remaining = remindAt.timeIntervalSince(date)
            events.append(
                ReminderEvent(
                    nodeId: node.id,
                    taskName: boss.name,
                    remindAt: remindAt,
                    leadTimeMinutes: leadMinutes,
                    remainingSeconds: remaining,
                    isOverdue: remaining < 0
                )
            )
        }
        return events
    }

    public func reset(for nodeId: UUID) {
        firedReminders.removeValue(forKey: nodeId)
    }

    public func resetAll() {
        firedReminders.removeAll()
    }
}
