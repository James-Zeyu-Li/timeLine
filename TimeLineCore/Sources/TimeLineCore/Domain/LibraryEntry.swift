import Foundation

public enum DeadlineStatus: String, Codable, Equatable {
    case active
    case expired
    case archived
}

public struct LibraryEntry: Identifiable, Codable, Equatable {
    public let templateId: UUID
    public var addedAt: Date
    public var deadlineStatus: DeadlineStatus
    
    public var id: UUID {
        templateId
    }
    
    public init(
        templateId: UUID,
        addedAt: Date = Date(),
        deadlineStatus: DeadlineStatus = .active
    ) {
        self.templateId = templateId
        self.addedAt = addedAt
        self.deadlineStatus = deadlineStatus
    }
    
    private enum CodingKeys: String, CodingKey {
        case templateId
        case addedAt
        case deadlineStatus
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.templateId = try container.decode(UUID.self, forKey: .templateId)
        self.addedAt = try container.decode(Date.self, forKey: .addedAt)
        self.deadlineStatus = try container.decodeIfPresent(DeadlineStatus.self, forKey: .deadlineStatus) ?? .active
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(templateId, forKey: .templateId)
        try container.encode(addedAt, forKey: .addedAt)
        try container.encode(deadlineStatus, forKey: .deadlineStatus)
    }
}
