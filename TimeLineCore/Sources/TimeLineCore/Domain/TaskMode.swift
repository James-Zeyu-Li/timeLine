import Foundation

public enum TaskMode: Codable, Equatable, Hashable {
    case focusStrictFixed
    case focusGroupFlexible
    case reminderOnly
    
    // MARK: - Compatibility ID
    public var id: String {
        switch self {
        case .focusStrictFixed: return "focusStrictFixed"
        case .focusGroupFlexible: return "focusGroupFlexible"
        case .reminderOnly: return "reminderOnly"
        }
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case type
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
            case "dungeonRaid": self = .focusGroupFlexible
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
            self = .focusGroupFlexible
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
        }
    }
}
