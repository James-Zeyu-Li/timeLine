import Foundation

public enum RepeatRule: Codable, Equatable {
    case none
    case daily
    case weekly(days: Set<Int>) // 1=Sun, 2=Mon...
    case monthly(days: Set<Int>)
    
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
