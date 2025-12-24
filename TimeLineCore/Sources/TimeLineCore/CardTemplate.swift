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
    
    public init(
        id: UUID = UUID(),
        title: String,
        icon: String = "bolt.fill",
        defaultDuration: TimeInterval = 1500,
        tags: [String] = [],
        energyColor: EnergyColorToken = .focus,
        category: TaskCategory = .work,
        style: BossStyle = .focus
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.defaultDuration = defaultDuration
        self.tags = tags
        self.energyColor = energyColor
        self.category = category
        self.style = style
    }
}
