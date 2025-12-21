import Foundation

public enum RepeatRule: Codable, Equatable {
    case none
    case daily
    case weekly(days: Set<Int>) // 1=Sun, 2=Mon...
    case monthly(days: Set<Int>)
    
    // Helper to check if it matches a date
    public func matches(date: Date) -> Bool {
        let calendar = Calendar.current
        switch self {
        case .none:
            return false
        case .daily:
            return true
        case .weekly(let days):
            let weekday = calendar.component(.weekday, from: date)
            return days.contains(weekday)
        case .monthly(let days):
            let day = calendar.component(.day, from: date)
            return days.contains(day)
        }
    }
}

public enum TaskCategory: String, Codable, CaseIterable {
    case work, study, rest, gym, other
    
    public var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .study: return "book.fill"
        case .rest: return "cup.api.fill" // coffee cup
        case .gym: return "dumbbell.fill"
        case .other: return "star.fill"
        }
    }
}

public struct TaskTemplate: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var style: BossStyle
    public var duration: TimeInterval? // For focus or event duration
    public var fixedTime: DateComponents? // For scheduled (e.g., 5 PM)
    public var repeatRule: RepeatRule
    public var category: TaskCategory
    
    public init(id: UUID = UUID(), title: String, style: BossStyle = .focus, duration: TimeInterval? = nil, fixedTime: DateComponents? = nil, repeatRule: RepeatRule = .none, category: TaskCategory = .work) {
        self.id = id
        self.title = title
        self.style = style
        self.duration = duration
        self.fixedTime = fixedTime
        self.repeatRule = repeatRule
        self.category = category
    }
}
