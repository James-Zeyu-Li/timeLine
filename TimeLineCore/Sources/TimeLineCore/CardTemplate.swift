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
    public var fixedTime: DateComponents?
    public var repeatRule: RepeatRule

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case icon
        case defaultDuration
        case tags
        case energyColor
        case category
        case style
        case fixedTime
        case repeatRule
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
        fixedTime: DateComponents? = nil,
        repeatRule: RepeatRule = .none
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.defaultDuration = defaultDuration
        self.tags = tags
        self.energyColor = energyColor
        self.category = category
        self.style = style
        self.fixedTime = fixedTime
        self.repeatRule = repeatRule
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
        self.fixedTime = try container.decodeIfPresent(DateComponents.self, forKey: .fixedTime)
        self.repeatRule = try container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule) ?? .none
    }
}
