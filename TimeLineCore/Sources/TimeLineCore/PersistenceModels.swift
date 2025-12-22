import Foundation

/// Represents the top-level state of the application for persistence.
public struct AppState: Codable {
    public var version: Int = 1
    public var lastSeenAt: Date
    public var daySession: DaySession // DaySession needs to be Codable
    public var engineState: BattleSnapshot?
    public var history: [DailyFunctionality] // Stats History
    public var templates: [TaskTemplate]
    public var spawnedKeys: Set<String> // Ledger for de-duplication
    
    public init(lastSeenAt: Date, daySession: DaySession, engineState: BattleSnapshot?, history: [DailyFunctionality], templates: [TaskTemplate] = [], spawnedKeys: Set<String> = []) {
        self.lastSeenAt = lastSeenAt
        self.daySession = daySession
        self.engineState = engineState
        self.history = history
        self.templates = templates
        self.spawnedKeys = spawnedKeys
    }
    
    // Manual decoding to handle missing "templates" field in old saves
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decode(Int.self, forKey: .version)
        self.lastSeenAt = try container.decode(Date.self, forKey: .lastSeenAt)
        self.daySession = try container.decode(DaySession.self, forKey: .daySession)
        self.engineState = try container.decodeIfPresent(BattleSnapshot.self, forKey: .engineState)
        self.history = try container.decode(Array<DailyFunctionality>.self, forKey: .history)
        self.templates = try container.decodeIfPresent([TaskTemplate].self, forKey: .templates) ?? []
        self.spawnedKeys = try container.decodeIfPresent(Set<String>.self, forKey: .spawnedKeys) ?? []
    }
}

/// A snapshot of the BattleEngine's active state.
public struct BattleSnapshot: Codable {
    public let boss: Boss
    public let state: BattleState
    public let startTime: Date
    public let elapsedBeforeLastSave: TimeInterval
    public let wastedTime: TimeInterval
    public let isImmune: Bool
    public let immunityCount: Int
    public let distractionStartTime: Date?
    public let totalFocusedHistoryToday: TimeInterval?
    public let history: [DailyFunctionality]?
    
    public init(boss: Boss, state: BattleState, startTime: Date, elapsedBeforeLastSave: TimeInterval, wastedTime: TimeInterval, isImmune: Bool, immunityCount: Int, distractionStartTime: Date?, totalFocusedHistoryToday: TimeInterval?, history: [DailyFunctionality]?) {
        self.boss = boss
        self.state = state
        self.startTime = startTime
        self.elapsedBeforeLastSave = elapsedBeforeLastSave
        self.wastedTime = wastedTime
        self.isImmune = isImmune
        self.immunityCount = immunityCount
        self.distractionStartTime = distractionStartTime
        self.totalFocusedHistoryToday = totalFocusedHistoryToday
        self.history = history
    }
}

/// Statistics for a single day (History).
public struct DailyFunctionality: Codable {
    public let date: Date
    public let totalFocusedTime: TimeInterval
    public let totalWastedTime: TimeInterval
    public let sessionsCount: Int
    
    public init(date: Date, totalFocusedTime: TimeInterval, totalWastedTime: TimeInterval, sessionsCount: Int) {
        self.date = date
        self.totalFocusedTime = totalFocusedTime
        self.totalWastedTime = totalWastedTime
        self.sessionsCount = sessionsCount
    }
}
