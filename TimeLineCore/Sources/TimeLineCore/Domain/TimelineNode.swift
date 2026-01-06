import Foundation

public enum NodeType: Equatable, Codable {
    case battle(Boss)
    case bonfire(TimeInterval)
    case treasure
}

public struct TimelineNode: Identifiable, Equatable, Codable {
    public let id: UUID
    public var type: NodeType
    public var isCompleted: Bool
    public var isLocked: Bool
    public var taskModeOverride: TaskMode?
    
    public init(
        id: UUID = UUID(),
        type: NodeType,
        isCompleted: Bool = false,
        isLocked: Bool,
        taskModeOverride: TaskMode? = nil
    ) {
        self.id = id
        self.type = type
        self.isCompleted = isCompleted
        self.isLocked = isLocked
        self.taskModeOverride = taskModeOverride
    }
    
    public func effectiveTaskMode(templateLookup: (UUID) -> CardTemplate?) -> TaskMode {
        if let override = taskModeOverride {
            return override
        }
        guard case .battle(let boss) = type,
              let templateId = boss.templateId,
              let template = templateLookup(templateId) else {
            return .focusStrictFixed
        }
        return template.taskMode
    }

    public func effectiveTaskBehavior(templateLookup: (UUID) -> CardTemplate?) -> TaskBehavior {
        if let override = taskModeOverride, override == .reminderOnly {
            return .reminder
        }
        guard case .battle(let boss) = type else { return .battle }
        if boss.remindAt != nil {
            return .reminder
        }
        if boss.style == .passive {
            return .reminder
        }
        if let templateId = boss.templateId,
           let template = templateLookup(templateId) {
            if template.taskMode == .reminderOnly {
                return .reminder
            }
            if template.style == .passive {
                return .reminder
            }
            if template.remindAt != nil {
                return .reminder
            }
        }
        return .battle
    }
}
