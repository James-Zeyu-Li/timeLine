import Foundation
import Combine
import TimeLineCore

public class StatsViewModel: ObservableObject {
    // MARK: - All Time Stats
    @Published public var totalFocusedAllTime: TimeInterval = 0
    @Published public var totalSessionsAllTime: Int = 0
    
    // MARK: - Existing Stats
    @Published public var heatmapData: [Date: Int] = [:] // Date (normalized) -> Level (0-4)
    @Published public var weeklyFocusedText: String = "0m"
    @Published public var weeklyWastedText: String = "0m"
    @Published public var sessionsCountText: String = "0"
    @Published public var weekBars: [WeekBar] = []
    @Published public var weekStart: Date = Calendar.current.startOfDay(for: Date())
    @Published public var weekEnd: Date = Calendar.current.startOfDay(for: Date())
    
    // MARK: - Grid Configuration
    public let daysInGrid = 365
    public var gridDates: [Date] = []
    
    private var cachedHistory: [DailyFunctionality] = []
    private var weekStartOverride: Date?
    
    public init() {
        processHistory([], weekStartOverride: nil)
        generateGridDates()
    }
    
    // For Preview/Testing
    public init(history: [DailyFunctionality], weekStartOverride: Date? = nil) {
        processHistory(history, weekStartOverride: weekStartOverride)
        generateGridDates()
    }
    
    private func generateGridDates() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var dates: [Date] = []
        for i in 0..<daysInGrid {
            if let date = calendar.date(byAdding: .day, value: -((daysInGrid - 1) - i), to: today) {
                dates.append(date)
            }
        }
        self.gridDates = dates
    }
    
    public func processHistory(_ history: [DailyFunctionality], weekStartOverride: Date? = nil) {
        cachedHistory = history
        self.weekStartOverride = weekStartOverride
        
        // 0. All-Time Stats
        totalFocusedAllTime = history.reduce(0) { $0 + $1.totalFocusedTime }
        totalSessionsAllTime = history.reduce(0) { $0 + $1.sessionsCount }
        
        // 1. Buckets for Heatmap
        var map: [Date: Int] = [:]
        for day in history {
            let date = Calendar.current.startOfDay(for: day.date)
            let level = calculateIntensity(focusedTime: day.totalFocusedTime)
            map[date] = level
        }
        self.heatmapData = map
        
        // 2. Weekly Stats (Mon-Sun)
        let calendar = calendarWithMondayStart()
        let referenceDate = weekStartOverride ?? Date()
        let today = calendar.startOfDay(for: referenceDate)
        
        if let interval = calendar.dateInterval(of: .weekOfYear, for: today) {
            weekStart = interval.start
            weekEnd = calendar.date(byAdding: .day, value: 6, to: interval.start) ?? interval.start
            
            var entriesByDate: [Date: DailyFunctionality] = [:]
            for entry in history {
                let key = calendar.startOfDay(for: entry.date)
                entriesByDate[key] = entry
            }
            
            var bars: [WeekBar] = []
            for offset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { continue }
                let key = calendar.startOfDay(for: date)
                let entry = entriesByDate[key]
                bars.append(
                    WeekBar(
                        date: key,
                        focused: entry?.totalFocusedTime ?? 0,
                        wasted: entry?.totalWastedTime ?? 0,
                        sessions: entry?.sessionsCount ?? 0
                    )
                )
            }
            weekBars = bars
            
            let totalFocused = bars.reduce(0) { $0 + $1.focused }
            let totalWasted = bars.reduce(0) { $0 + $1.wasted }
            let count = bars.reduce(0) { $0 + $1.sessions }
            
            weeklyFocusedText = TimeFormatter.formatStats(totalFocused)
            weeklyWastedText = TimeFormatter.formatStats(totalWasted)
            sessionsCountText = "\(count)"
        } else {
            weekBars = []
            weeklyFocusedText = "0m"
            weeklyWastedText = "0m"
            sessionsCountText = "0"
        }
    }

    public func setWeekStart(_ date: Date?) {
        weekStartOverride = date
        processHistory(cachedHistory, weekStartOverride: date)
    }
    
    private func calculateIntensity(focusedTime: TimeInterval) -> Int {
        let minutes = focusedTime / 60
        if minutes == 0 { return 0 }
        if minutes < 15 { return 1 }
        if minutes < 45 { return 2 }
        if minutes < 90 { return 3 }
        return 4
    }
    
    private func calendarWithMondayStart() -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }
}

public struct WeekBar: Identifiable, Equatable {
    public var id: Date { date }
    public let date: Date
    public let focused: TimeInterval
    public let wasted: TimeInterval
    public let sessions: Int
    
    public var total: TimeInterval {
        focused + wasted
    }
}
