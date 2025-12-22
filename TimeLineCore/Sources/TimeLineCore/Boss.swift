import Foundation

public struct Boss: Identifiable, Equatable, Codable {
    public let id: UUID
    public var name: String
    public var maxHp: TimeInterval
    public var currentHp: TimeInterval
    public var style: BossStyle
    public var category: TaskCategory
    public var templateId: UUID?
    
    public init(id: UUID = UUID(), name: String, maxHp: TimeInterval, style: BossStyle = .focus, category: TaskCategory = .work, templateId: UUID? = nil) {
        self.id = id
        self.name = name
        self.maxHp = maxHp
        self.currentHp = maxHp
        self.style = style
        self.category = category
        self.templateId = templateId
    }
    
    // Custom Decoding for Backward Compatibility
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.maxHp = try container.decode(TimeInterval.self, forKey: .maxHp)
        self.currentHp = try container.decode(TimeInterval.self, forKey: .currentHp)
        
        // Provide default .focus if style is missing (Old Save File)
        self.style = try container.decodeIfPresent(BossStyle.self, forKey: .style) ?? .focus
        self.category = try container.decodeIfPresent(TaskCategory.self, forKey: .category) ?? .work
        self.templateId = try container.decodeIfPresent(UUID.self, forKey: .templateId)
    }
}
