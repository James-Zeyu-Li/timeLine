import Foundation

// MARK: - Card Status

public enum CardStatus: String, Codable {
    case draft
    case placed
    case running
    case done
}

// MARK: - Card Instance

public struct CardInstance: Identifiable, Codable, Equatable {
    public let instanceId: UUID
    public let templateId: UUID
    public var title: String
    public var duration: TimeInterval
    public var anchorNodeId: UUID?
    public var status: CardStatus
    
    // MARK: - Identifiable
    
    public var id: UUID { instanceId }
    
    // MARK: - Init
    
    public init(
        instanceId: UUID = UUID(),
        templateId: UUID,
        title: String,
        duration: TimeInterval,
        anchorNodeId: UUID? = nil,
        status: CardStatus = .draft
    ) {
        self.instanceId = instanceId
        self.templateId = templateId
        self.title = title
        self.duration = duration
        self.anchorNodeId = anchorNodeId
        self.status = status
    }
    
    // MARK: - Factory
    
    public static func make(from template: CardTemplate) -> CardInstance {
        CardInstance(
            instanceId: UUID(),
            templateId: template.id,
            title: template.title,
            duration: template.defaultDuration,
            anchorNodeId: nil,
            status: .draft
        )
    }
}
