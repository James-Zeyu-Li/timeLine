import Foundation

// MARK: - Energy Color Token

public enum EnergyColorToken: String, Codable, CaseIterable {
    case focus
    case passive
    case rest
    case gym
    case creative
}

// MARK: - Card Template

public struct CardTemplate: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var icon: String
    public var defaultDuration: TimeInterval
    public var tags: [String]
    public var energyColor: EnergyColorToken
    public var category: TaskCategory
    public var style: BossStyle
    public var taskMode: TaskMode
    public var fixedTime: DateComponents?
    public var repeatRule: RepeatRule
    public var remindAt: Date?
    public var leadTimeMinutes: Int
    public var isEphemeral: Bool
    public var deadlineWindowDays: Int?
    public var deadlineAt: Date?
    public var lastActivatedAt: Date?  // For staleness tracking in tiered library

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case icon
        case defaultDuration
        case tags
        case energyColor
        case category
        case style
        case taskMode
        case fixedTime
        case repeatRule
        case remindAt
        case leadTimeMinutes
        case isEphemeral
        case deadlineWindowDays
        case deadlineAt
        case lastActivatedAt
    }
    
    public init(
        id: UUID = UUID(),
        title: String,
        icon: String = "bolt.fill",
        defaultDuration: TimeInterval = 1500,
        tags: [String] = [],
        energyColor: EnergyColorToken = .focus,
        category: TaskCategory = .work,
        style: BossStyle = .focus,
        taskMode: TaskMode = .focusStrictFixed,
        fixedTime: DateComponents? = nil,
        repeatRule: RepeatRule = .none,
        remindAt: Date? = nil,
        leadTimeMinutes: Int = 0,
        isEphemeral: Bool = false,
        deadlineWindowDays: Int? = nil,
        deadlineAt: Date? = nil,
        lastActivatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.defaultDuration = defaultDuration
        self.tags = tags
        self.energyColor = energyColor
        self.category = category
        self.style = style
        self.taskMode = taskMode
        self.fixedTime = fixedTime
        self.repeatRule = repeatRule
        self.remindAt = remindAt
        self.leadTimeMinutes = leadTimeMinutes
        self.isEphemeral = isEphemeral
        self.deadlineWindowDays = deadlineWindowDays
        self.deadlineAt = deadlineAt
        self.lastActivatedAt = lastActivatedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.icon = try container.decode(String.self, forKey: .icon)
        self.defaultDuration = try container.decode(TimeInterval.self, forKey: .defaultDuration)
        self.tags = try container.decode([String].self, forKey: .tags)
        self.energyColor = try container.decode(EnergyColorToken.self, forKey: .energyColor)
        self.category = try container.decode(TaskCategory.self, forKey: .category)
        self.style = try container.decode(BossStyle.self, forKey: .style)
        self.taskMode = try container.decodeIfPresent(TaskMode.self, forKey: .taskMode) ?? .focusStrictFixed
        self.fixedTime = try container.decodeIfPresent(DateComponents.self, forKey: .fixedTime)
        self.repeatRule = try container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule) ?? .none
        self.remindAt = try container.decodeIfPresent(Date.self, forKey: .remindAt)
        self.leadTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .leadTimeMinutes) ?? 0
        self.isEphemeral = try container.decodeIfPresent(Bool.self, forKey: .isEphemeral) ?? false
        self.deadlineWindowDays = try container.decodeIfPresent(Int.self, forKey: .deadlineWindowDays)
        self.deadlineAt = try container.decodeIfPresent(Date.self, forKey: .deadlineAt)
        self.lastActivatedAt = try container.decodeIfPresent(Date.self, forKey: .lastActivatedAt)
    }
}
