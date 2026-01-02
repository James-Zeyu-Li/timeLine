import Foundation

public struct LibraryEntry: Identifiable, Codable, Equatable {
    public let templateId: UUID
    public var addedAt: Date
    public var deadline: Date?
    
    public var id: UUID {
        templateId
    }
    
    public init(
        templateId: UUID,
        addedAt: Date = Date(),
        deadline: Date? = nil
    ) {
        self.templateId = templateId
        self.addedAt = addedAt
        self.deadline = deadline
    }
}
