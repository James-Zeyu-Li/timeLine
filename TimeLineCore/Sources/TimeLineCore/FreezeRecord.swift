import Foundation

public struct FreezeRecord: Codable, Equatable {
    public let startedAt: Date
    public let endedAt: Date
    public let duration: TimeInterval
    public let bossName: String?
    
    public init(startedAt: Date, endedAt: Date, duration: TimeInterval, bossName: String?) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.bossName = bossName
    }
}
