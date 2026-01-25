import Foundation
// Forced Rebuild Touch

public struct StagedTask: Identifiable, Equatable, Codable {
    public var id: UUID
    public var template: CardTemplate
    public var finishBy: FinishBySelection
    
    public init(id: UUID = UUID(), template: CardTemplate, finishBy: FinishBySelection) {
        self.id = id
        self.template = template
        self.finishBy = finishBy
    }
    
    public static func == (lhs: StagedTask, rhs: StagedTask) -> Bool {
        lhs.id == rhs.id
    }
}

public enum FinishBySelection: Equatable, CaseIterable, Codable, Hashable {
    case tonight
    case tomorrow
    case next3Days
    case thisWeek
    case none
    case pickDate(Date)
    
    public static var allCases: [FinishBySelection] {
        [.tonight, .tomorrow, .next3Days, .thisWeek, .none]
    }
    
    public var displayName: String {
        switch self {
        case .tonight:
            return "今晚"
        case .tomorrow:
            return "明天"
        case .next3Days:
            return "未来3天"
        case .thisWeek:
            return "本周内"
        case .none:
            return "无截止"
        case .pickDate(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    public var iconName: String {
        switch self {
        case .tonight:
            return "moon.stars.fill"
        case .tomorrow:
            return "sun.max.fill"
        case .next3Days:
            return "calendar.badge.clock"
        case .thisWeek:
            return "calendar"
        case .none:
            return "infinity"
        case .pickDate:
            return "calendar.circle"
        }
    }
    
    public enum GroupKey: Hashable {
        case tonight
        case tomorrow
        case next3Days
        case thisWeek
        case none
        case customDate(Date)
        
        public var displayName: String {
            switch self {
            case .tonight:
                return "今晚"
            case .tomorrow:
                return "明天"
            case .next3Days:
                return "未来3天"
            case .thisWeek:
                return "本周内"
            case .none:
                return "无截止"
            case .customDate(let date):
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        }
        
        public var sortOrder: Int {
            switch self {
            case .tonight:
                return 0
            case .tomorrow:
                return 1
            case .next3Days:
                return 2
            case .thisWeek:
                return 3
            case .customDate:
                return 4
            case .none:
                return 5
            }
        }
        
        public func hash(into hasher: inout Hasher) {
            switch self {
            case .tonight:
                hasher.combine("tonight")
            case .tomorrow:
                hasher.combine("tomorrow")
            case .next3Days:
                hasher.combine("next3Days")
            case .thisWeek:
                hasher.combine("thisWeek")
            case .none:
                hasher.combine("none")
            case .customDate(let date):
                hasher.combine("customDate")
                hasher.combine(date)
            }
        }
        
        public static func == (lhs: GroupKey, rhs: GroupKey) -> Bool {
            switch (lhs, rhs) {
            case (.tonight, .tonight), (.tomorrow, .tomorrow), (.next3Days, .next3Days), (.thisWeek, .thisWeek), (.none, .none):
                return true
            case (.customDate(let d1), .customDate(let d2)):
                return d1 == d2
            default:
                return false
            }
        }
    }
    
    public var groupKey: GroupKey {
        switch self {
        case .tonight:
            return .tonight
        case .tomorrow:
            return .tomorrow
        case .next3Days:
            return .next3Days
        case .thisWeek:
            return .thisWeek
        case .none:
            return .none
        case .pickDate(let date):
            return .customDate(date)
        }
    }
    
    public func toDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .tonight:
            return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: now)
        case .next3Days:
            return calendar.date(byAdding: .day, value: 3, to: now)
        case .thisWeek:
            return calendar.date(byAdding: .day, value: 7, to: now)
        case .none:
            return nil
        case .pickDate(let date):
            return date
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .tonight:
            hasher.combine("tonight")
        case .tomorrow:
            hasher.combine("tomorrow")
        case .next3Days:
            hasher.combine("next3Days")
        case .thisWeek:
            hasher.combine("thisWeek")
        case .none:
            hasher.combine("none")
        case .pickDate(let date):
            hasher.combine("pickDate")
            hasher.combine(date)
        }
    }
    
    public var sortOrder: Int {
        switch self {
        case .tonight:
            return 0
        case .tomorrow:
            return 1
        case .next3Days:
            return 2
        case .thisWeek:
            return 3
        case .pickDate:
            return 4
        case .none:
            return 5
        }
    }
}
