import Foundation
import Combine
import TimeLineCore

public enum StatsTimeRange: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case year = "Year"
    public var id: String { rawValue }
}

public class StatsViewModel: ObservableObject {
    // MARK: - All Time Stats
    @Published public var totalFocusedAllTime: TimeInterval = 0
    @Published public var totalSessionsAllTime: Int = 0
    
    // MARK: - New Stats (Phase 18.7)
    @Published public var currentStreak: Int = 0
    @Published public var weeklyGrowthPercent: Int = 0
    @Published public var totalQuests: Int = 0
    
    // MARK: - Time Range Selection
    @Published public var selectedRange: StatsTimeRange = .week
    
    // MARK: - Range-Specific Stats
    @Published public var heatmapData: [Date: Int] = [:] // Date (normalized) -> Level (0-4)
    @Published public var rangeFocusedText: String = "0m"
    @Published public var rangeWastedText: String = "0m"
    @Published public var rangeSessionsText: String = "0"
    @Published public var rangeBars: [WeekBar] = []
    @Published public var rangeStart: Date = Calendar.current.startOfDay(for: Date())
    @Published public var rangeEnd: Date = Calendar.current.startOfDay(for: Date())
    @Published public var rangeGrowthPercent: Int = 0
    
    // MARK: - Legacy Properties (for backward compatibility)
    public var weeklyFocusedText: String { rangeFocusedText }
    public var weeklyWastedText: String { rangeWastedText }
    public var sessionsCountText: String { rangeSessionsText }
    public var weekBars: [WeekBar] { rangeBars }
    public var weekStart: Date { rangeStart }
    public var weekEnd: Date { rangeEnd }
    // public var weeklyGrowthPercent: Int { rangeGrowthPercent } // Redundant with stored property
    
    // MARK: - Grid Configuration
    public let daysInGrid = 365
    public var gridDates: [Date] = []
    
    private var cachedHistory: [DailyFunctionality] = []
    private var cachedSpecimens: SpecimenCollection?
    private var weekStartOverride: Date?
    
    public init() {
        processHistory([], specimens: nil, weekStartOverride: nil)
        generateGridDates()
    }
    
    // For Preview/Testing
    public init(history: [DailyFunctionality], specimens: SpecimenCollection? = nil, weekStartOverride: Date? = nil) {
        processHistory(history, specimens: specimens, weekStartOverride: weekStartOverride)
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
    
    public func processHistory(_ history: [DailyFunctionality], specimens: SpecimenCollection? = nil, weekStartOverride: Date? = nil) {
        cachedHistory = history
        cachedSpecimens = specimens
        self.weekStartOverride = weekStartOverride
        
        // 0. All-Time Stats
        totalFocusedAllTime = history.reduce(0) { $0 + $1.totalFocusedTime }
        totalSessionsAllTime = history.reduce(0) { $0 + $1.sessionsCount }
        
        // 0.1 New Stats
        currentStreak = StatsAggregator.calculateCurrentStreak(history: history)
        if let specimens = specimens {
            totalQuests = specimens.specimens.count
        } else {
            // Fallback if no collection: use sessions as proxy (or 0)
            totalQuests = totalSessionsAllTime
        }
        
        // 1. Buckets for Heatmap
        var map: [Date: Int] = [:]
        for day in history {
            let date = Calendar.current.startOfDay(for: day.date)
            let level = calculateIntensity(focusedTime: day.totalFocusedTime)
            map[date] = level
        }
        self.heatmapData = map
        
        // 2. Update range-specific stats based on selected range
        updateRangeStats()
    }
    
    public func updateSelectedRange(_ range: StatsTimeRange) {
        selectedRange = range
        updateRangeStats()
    }
    
    private func updateRangeStats() {
        let calendar = calendarWithMondayStart()
        let referenceDate = weekStartOverride ?? Date()
        let today = calendar.startOfDay(for: referenceDate)
        
        var entriesByDate: [Date: DailyFunctionality] = [:]
        for entry in cachedHistory {
            let key = calendar.startOfDay(for: entry.date)
            entriesByDate[key] = entry
        }
        
        switch selectedRange {
        case .day:
            updateDayStats(today: today, entriesByDate: entriesByDate, calendar: calendar)
        case .week:
            updateWeekStats(today: today, entriesByDate: entriesByDate, calendar: calendar)
        case .year:
            updateYearStats(today: today, entriesByDate: entriesByDate, calendar: calendar)
        }
    }
    
    private func updateDayStats(today: Date, entriesByDate: [Date: DailyFunctionality], calendar: Calendar) {
        rangeStart = today
        rangeEnd = today
        
        let todayEntry = entriesByDate[today]
        let focused = todayEntry?.totalFocusedTime ?? 0
        let wasted = todayEntry?.totalWastedTime ?? 0
        let sessions = todayEntry?.sessionsCount ?? 0
        
        rangeFocusedText = TimeFormatter.formatStats(focused)
        rangeWastedText = TimeFormatter.formatStats(wasted)
        rangeSessionsText = "\(sessions)"
        
        // Single bar for today
        rangeBars = [WeekBar(date: today, focused: focused, wasted: wasted, sessions: sessions)]
        
        // Calculate daily growth (vs yesterday)
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           let yesterdayEntry = entriesByDate[yesterday] {
            let yesterdayFocused = yesterdayEntry.totalFocusedTime
            rangeGrowthPercent = StatsAggregator.calculateWeeklyGrowth(
                currentWeekFocused: focused,
                previousWeekFocused: yesterdayFocused
            )
        } else {
            rangeGrowthPercent = 0
        }
    }
    
    private func updateWeekStats(today: Date, entriesByDate: [Date: DailyFunctionality], calendar: Calendar) {
        if let interval = calendar.dateInterval(of: .weekOfYear, for: today) {
            rangeStart = interval.start
            rangeEnd = calendar.date(byAdding: .day, value: 6, to: interval.start) ?? interval.start
            
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
            rangeBars = bars
            
            let totalFocused = bars.reduce(0) { $0 + $1.focused }
            let totalWasted = bars.reduce(0) { $0 + $1.wasted }
            let count = bars.reduce(0) { $0 + $1.sessions }
            
            rangeFocusedText = TimeFormatter.formatStats(totalFocused)
            rangeWastedText = TimeFormatter.formatStats(totalWasted)
            rangeSessionsText = "\(count)"
            
            // Calculate Weekly Growth
            if let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: rangeStart) {
                let prevWeekEnd = rangeStart
                let prevWeekFocused = cachedHistory.filter {
                    let d = $0.date
                    return d >= prevWeekStart && d < prevWeekEnd
                }.reduce(0) { $0 + $1.totalFocusedTime }
                
                rangeGrowthPercent = StatsAggregator.calculateWeeklyGrowth(
                   currentWeekFocused: totalFocused,
                   previousWeekFocused: prevWeekFocused
                )
            } else {
                rangeGrowthPercent = 0
            }
        } else {
            rangeBars = []
            rangeFocusedText = "0m"
            rangeWastedText = "0m"
            rangeSessionsText = "0"
            rangeGrowthPercent = 0
        }
    }
    
    private func updateYearStats(today: Date, entriesByDate: [Date: DailyFunctionality], calendar: Calendar) {
        // Get start and end of current year
        let year = calendar.component(.year, from: today)
        rangeStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? today
        rangeEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? today
        
        // Filter history for current year
        let yearHistory = cachedHistory.filter {
            calendar.component(.year, from: $0.date) == year
        }
        
        let totalFocused = yearHistory.reduce(0) { $0 + $1.totalFocusedTime }
        let totalWasted = yearHistory.reduce(0) { $0 + $1.totalWastedTime }
        let totalSessions = yearHistory.reduce(0) { $0 + $1.sessionsCount }
        
        rangeFocusedText = TimeFormatter.formatStats(totalFocused)
        rangeWastedText = TimeFormatter.formatStats(totalWasted)
        rangeSessionsText = "\(totalSessions)"
        
        // Create monthly bars for the year
        var monthlyBars: [WeekBar] = []
        for month in 1...12 {
            guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { continue }
            
            let monthHistory = yearHistory.filter {
                calendar.component(.month, from: $0.date) == month
            }
            
            let monthFocused = monthHistory.reduce(0) { $0 + $1.totalFocusedTime }
            let monthWasted = monthHistory.reduce(0) { $0 + $1.totalWastedTime }
            let monthSessions = monthHistory.reduce(0) { $0 + $1.sessionsCount }
            
            monthlyBars.append(WeekBar(
                date: monthStart,
                focused: monthFocused,
                wasted: monthWasted,
                sessions: monthSessions
            ))
        }
        rangeBars = monthlyBars
        
        // Calculate yearly growth (vs previous year)
        let prevYear = year - 1
        let prevYearHistory = cachedHistory.filter {
            calendar.component(.year, from: $0.date) == prevYear
        }
        let prevYearFocused = prevYearHistory.reduce(0) { $0 + $1.totalFocusedTime }
        
        rangeGrowthPercent = StatsAggregator.calculateWeeklyGrowth(
            currentWeekFocused: totalFocused,
            previousWeekFocused: prevYearFocused
        )
    }

    public func setWeekStart(_ date: Date?) {
        weekStartOverride = date
        processHistory(cachedHistory, specimens: cachedSpecimens, weekStartOverride: date)
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
