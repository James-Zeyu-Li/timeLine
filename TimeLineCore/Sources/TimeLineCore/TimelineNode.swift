import Foundation

public enum NodeType: Equatable, Codable {
    case battle(Boss)
    case bonfire(TimeInterval)
    case treasure
}

public struct TimelineNode: Identifiable, Equatable, Codable {
    public let id: UUID
    public var type: NodeType
    public var isCompleted: Bool
    public var isLocked: Bool
    
    public init(id: UUID = UUID(), type: NodeType, isCompleted: Bool = false, isLocked: Bool) {
        self.id = id
        self.type = type
        self.isCompleted = isCompleted
        self.isLocked = isLocked
    }
}
