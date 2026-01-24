import Foundation

/// Represents the top-level state of the application for persistence.
public struct AppState: Codable {
    public var version: Int = 1
    public var lastSeenAt: Date
    public var daySession: DaySession // DaySession needs to be Codable
    public var engineState: BattleSnapshot?
    public var history: [DailyFunctionality] // Stats History
    public var cardTemplates: [CardTemplate]
    public var libraryEntries: [LibraryEntry]
    public var inbox: [UUID]
    public var spawnedKeys: Set<String> // Ledger for de-duplication
    
    private enum CodingKeys: String, CodingKey {
        case version
        case lastSeenAt
        case daySession
        case engineState
        case history
        case cardTemplates
        case libraryEntries
        case inbox
        case spawnedKeys
    }
    
    public init(
        lastSeenAt: Date,
        daySession: DaySession,
        engineState: BattleSnapshot?,
        history: [DailyFunctionality],
        cardTemplates: [CardTemplate] = [],
        libraryEntries: [LibraryEntry] = [],
        inbox: [UUID] = [],
        spawnedKeys: Set<String> = []
    ) {
        self.lastSeenAt = lastSeenAt
        self.daySession = daySession
        self.engineState = engineState
        self.history = history
        self.cardTemplates = cardTemplates
        self.libraryEntries = libraryEntries
        self.inbox = inbox
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
        self.cardTemplates = try container.decodeIfPresent([CardTemplate].self, forKey: .cardTemplates) ?? []
        self.libraryEntries = try container.decodeIfPresent([LibraryEntry].self, forKey: .libraryEntries) ?? []
        self.inbox = try container.decodeIfPresent([UUID].self, forKey: .inbox) ?? []
        self.spawnedKeys = try container.decodeIfPresent(Set<String>.self, forKey: .spawnedKeys) ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(lastSeenAt, forKey: .lastSeenAt)
        try container.encode(daySession, forKey: .daySession)
        try container.encodeIfPresent(engineState, forKey: .engineState)
        try container.encode(history, forKey: .history)
        try container.encode(cardTemplates, forKey: .cardTemplates)
        try container.encode(libraryEntries, forKey: .libraryEntries)
        try container.encode(inbox, forKey: .inbox)
        try container.encode(spawnedKeys, forKey: .spawnedKeys)
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
    public let freezeTokensUsed: Int?
    public let freezeHistory: [FreezeRecord]?
    public let freezeStartTime: Date?
    public let totalFocusedHistoryToday: TimeInterval?
    public let history: [DailyFunctionality]?
    public let stamina: StaminaSystem?
    
    private enum CodingKeys: String, CodingKey {
        case boss
        case state
        case startTime
        case elapsedBeforeLastSave
        case wastedTime
        case isImmune
        case immunityCount
        case distractionStartTime
        case freezeTokensUsed
        case freezeHistory
        case freezeStartTime
        case totalFocusedHistoryToday
        case history
        case stamina
    }
    
    public init(
        boss: Boss,
        state: BattleState,
        startTime: Date,
        elapsedBeforeLastSave: TimeInterval,
        wastedTime: TimeInterval,
        isImmune: Bool,
        immunityCount: Int,
        distractionStartTime: Date?,
        freezeTokensUsed: Int? = nil,
        freezeHistory: [FreezeRecord]? = nil,
        freezeStartTime: Date? = nil,
        totalFocusedHistoryToday: TimeInterval?,
        history: [DailyFunctionality]?,
        stamina: StaminaSystem? = nil
    ) {
        self.boss = boss
        self.state = state
        self.startTime = startTime
        self.elapsedBeforeLastSave = elapsedBeforeLastSave
        self.wastedTime = wastedTime
        self.isImmune = isImmune
        self.immunityCount = immunityCount
        self.distractionStartTime = distractionStartTime
        self.freezeTokensUsed = freezeTokensUsed
        self.freezeHistory = freezeHistory
        self.freezeStartTime = freezeStartTime
        self.totalFocusedHistoryToday = totalFocusedHistoryToday
        self.history = history
        self.stamina = stamina
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.boss = try container.decode(Boss.self, forKey: .boss)
        self.state = try container.decode(BattleState.self, forKey: .state)
        self.startTime = try container.decode(Date.self, forKey: .startTime)
        self.elapsedBeforeLastSave = try container.decode(TimeInterval.self, forKey: .elapsedBeforeLastSave)
        self.wastedTime = try container.decode(TimeInterval.self, forKey: .wastedTime)
        self.isImmune = try container.decode(Bool.self, forKey: .isImmune)
        self.immunityCount = try container.decode(Int.self, forKey: .immunityCount)
        self.distractionStartTime = try container.decodeIfPresent(Date.self, forKey: .distractionStartTime)
        self.freezeTokensUsed = try container.decodeIfPresent(Int.self, forKey: .freezeTokensUsed)
        self.freezeHistory = try container.decodeIfPresent([FreezeRecord].self, forKey: .freezeHistory)
        self.freezeStartTime = try container.decodeIfPresent(Date.self, forKey: .freezeStartTime)
        self.totalFocusedHistoryToday = try container.decodeIfPresent(TimeInterval.self, forKey: .totalFocusedHistoryToday)
        self.history = try container.decodeIfPresent([DailyFunctionality].self, forKey: .history)
        self.stamina = try container.decodeIfPresent(StaminaSystem.self, forKey: .stamina)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(boss, forKey: .boss)
        try container.encode(state, forKey: .state)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(elapsedBeforeLastSave, forKey: .elapsedBeforeLastSave)
        try container.encode(wastedTime, forKey: .wastedTime)
        try container.encode(isImmune, forKey: .isImmune)
        try container.encode(immunityCount, forKey: .immunityCount)
        try container.encodeIfPresent(distractionStartTime, forKey: .distractionStartTime)
        try container.encodeIfPresent(freezeTokensUsed, forKey: .freezeTokensUsed)
        try container.encodeIfPresent(freezeHistory, forKey: .freezeHistory)
        try container.encodeIfPresent(freezeStartTime, forKey: .freezeStartTime)
        try container.encodeIfPresent(totalFocusedHistoryToday, forKey: .totalFocusedHistoryToday)
        try container.encodeIfPresent(history, forKey: .history)
        try container.encodeIfPresent(stamina, forKey: .stamina)
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
