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
    public var isUnscheduled: Bool
    
    public init(
        id: UUID = UUID(),
        type: NodeType,
        isCompleted: Bool = false,
        isLocked: Bool,
        taskModeOverride: TaskMode? = nil,
        isUnscheduled: Bool = false
    ) {
        self.id = id
        self.type = type
        self.isCompleted = isCompleted
        self.isLocked = isLocked
        self.taskModeOverride = taskModeOverride
        self.isUnscheduled = isUnscheduled
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
            if template.remindAt != nil {
                return .reminder
            }
        }
        return .battle
    }

    // MARK: - Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case id, type, isCompleted, isLocked, taskModeOverride, isUnscheduled
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(NodeType.self, forKey: .type)
        self.isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        self.isLocked = try container.decode(Bool.self, forKey: .isLocked)
        self.taskModeOverride = try container.decodeIfPresent(TaskMode.self, forKey: .taskModeOverride)
        self.isUnscheduled = try container.decodeIfPresent(Bool.self, forKey: .isUnscheduled) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encodeIfPresent(taskModeOverride, forKey: .taskModeOverride)
        try container.encode(isUnscheduled, forKey: .isUnscheduled)
    }
}
