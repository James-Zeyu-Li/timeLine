import Foundation

public struct EnemyNode: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var isDefeated: Bool
    public var estimatedHP: TimeInterval // Estimated duration
    
    public init(id: UUID = UUID(), title: String, isDefeated: Bool = false, estimatedHP: TimeInterval) {
        self.id = id
        self.title = title
        self.isDefeated = isDefeated
        self.estimatedHP = estimatedHP
    }
}

public enum TaskMode: Codable, Equatable {
    case focusStrictFixed
    case focusGroupFlexible
    case reminderOnly
    case dungeonRaid(enemies: [EnemyNode])
    
    // MARK: - Compatibility ID
    public var id: String {
        switch self {
        case .focusStrictFixed: return "focusStrictFixed"
        case .focusGroupFlexible: return "focusGroupFlexible"
        case .reminderOnly: return "reminderOnly"
        case .dungeonRaid: return "dungeonRaid"
        }
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case type
        case enemies
    }
    
    private enum LegacyValues: String, Codable {
        case focusStrictFixed
        case focusGroupFlexible
        case reminderOnly
    }
    
    public init(from decoder: Decoder) throws {
        // Strategy: Try decoding as a legacy String first (SingleValueContainer).
        // If that fails, assume it's a new complex object (KeyedContainer).
        
        if let container = try? decoder.singleValueContainer(),
           let legacyString = try? container.decode(String.self) {
            switch legacyString {
            case "focusStrictFixed": self = .focusStrictFixed
            case "focusGroupFlexible": self = .focusGroupFlexible
            case "reminderOnly": self = .reminderOnly
            // Fallback for unknown legacy strings?
            default: self = .focusStrictFixed 
            }
            return
        }
        
        // Attempt complex object decoding
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "dungeonRaid":
            let enemies = try container.decode([EnemyNode].self, forKey: .enemies)
            self = .dungeonRaid(enemies: enemies)
        // Handle future complex types or complex versions of existing types
        case "focusStrictFixed": self = .focusStrictFixed
        case "focusGroupFlexible": self = .focusGroupFlexible
        case "reminderOnly": self = .reminderOnly
        default:
            self = .focusStrictFixed
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .focusStrictFixed, .focusGroupFlexible, .reminderOnly:
            var container = encoder.singleValueContainer()
            try container.encode(self.id)
            
        case .dungeonRaid(let enemies):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("dungeonRaid", forKey: .type)
            try container.encode(enemies, forKey: .enemies)
        }
    }
}
