import Foundation
import Combine
import TimeLineCore

public class StatsViewModel: ObservableObject {
    @Published public var heatmapData: [Date: Int] = [:] // Date (normalized) -> Level (0-4)
    @Published public var weeklyFocusedText: String = "0m"
    @Published public var weeklyWastedText: String = "0m"
    @Published public var sessionsCountText: String = "0"
    
    // Grid Configuration
    public let daysInGrid = 365
    public var gridDates: [Date] = []
    
    public init() {
        // Load data from Persistence
        let state = PersistenceManager.shared.load()
        let history = state?.history ?? []
        
        processHistory(history)
        generateGridDates()
    }
    
    // For Preview/Testing
    public init(history: [DailyFunctionality]) {
        processHistory(history)
        generateGridDates()
    }
    
    private func generateGridDates() {
        // Generate last 365 days ending today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // We want a grid that ends on Today? Or 52 weeks?
        // GitHub style: Rows=7 (Sun-Sat), Cols=52.
        // Let's simplified: Just a flat list of dates reversed or forward?
        // Usually visualised as Columns (Weeks). 
        // We will generate dates, the View will lay them out.
        // Let's generate from (Today - 364 days) to Today.
        
        var dates: [Date] = []
        for i in 0..<daysInGrid {
            if let date = calendar.date(byAdding: .day, value: -((daysInGrid - 1) - i), to: today) {
                dates.append(date)
            }
        }
        self.gridDates = dates
    }
    
    public func processHistory(_ history: [DailyFunctionality]) {
        // 1. Buckets for Heatmap
        var map: [Date: Int] = [:]
        for day in history {
            let date = Calendar.current.startOfDay(for: day.date)
            let level = calculateIntensity(focusedTime: day.totalFocusedTime)
            map[date] = level
        }
        self.heatmapData = map
        
        // 2. Weekly Stats (Last 7 Days)
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        
        let thisWeekSessions = history.filter { $0.date >= weekAgo }
        let (totalFocused, totalWasted, count) = StatsAggregator.aggregate(history: thisWeekSessions)
        
        self.weeklyFocusedText = format(totalFocused)
        self.weeklyWastedText = format(totalWasted)
        self.sessionsCountText = "\(count)"
    }
    
    private func calculateIntensity(focusedTime: TimeInterval) -> Int {
        let minutes = focusedTime / 60
        if minutes == 0 { return 0 }
        if minutes < 15 { return 1 }
        if minutes < 45 { return 2 }
        if minutes < 90 { return 3 }
        return 4
    }
    
    private func format(_ interval: TimeInterval) -> String {
        let m = Int(interval / 60)
        if m < 60 {
            return "\(m)m"
        } else {
            let h = m / 60
            let rem = m % 60
            return "\(h)h \(rem)m"
        }
    }
}
