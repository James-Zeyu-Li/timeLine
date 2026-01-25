import Foundation

public struct HabitatBlock: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var startTime: Date?       // Optional soft anchor (e.g. 09:00)
    public var memberTemplateIds: [UUID]
    
    // Computed total duration based on member templates
    // NOTE: This will require resolving templates from a store,
    // so here we might just store the IDs. The View/ViewModel calculates time.
    
    public init(
        id: UUID = UUID(),
        name: String,
        startTime: Date? = nil,
        memberTemplateIds: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.memberTemplateIds = memberTemplateIds
    }
}
