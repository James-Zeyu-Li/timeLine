import Foundation

/// Analyzes completed sessions to provide statistics.
public class StatsAggregator {
    
    /// Aggregates a list of DailyFunctionality stats into a weekly summary.
    /// Simplified for V0: Just sums everything.
    public static func aggregate(history: [DailyFunctionality]) -> (totalFocused: TimeInterval, totalWasted: TimeInterval, sessions: Int) {
        let totalFocused = history.reduce(0) { $0 + $1.totalFocusedTime }
        let totalWasted = history.reduce(0) { $0 + $1.totalWastedTime }
        let sessions = history.reduce(0) { $0 + $1.sessionsCount }
        return (totalFocused, totalWasted, sessions)
    }
    
    /// Checks if a session for today already exists in history, if so updates it, else appends.
    /// Returns the new history list.
    public static func updateHistory(history: [DailyFunctionality], session: DailyFunctionality) -> [DailyFunctionality] {
        var newHistory = history
        // Normalize dates to midnight for comparison
        let calendar = Calendar.current
        let sessionDate = calendar.startOfDay(for: session.date)
        
        if let index = newHistory.firstIndex(where: { calendar.startOfDay(for: $0.date) == sessionDate }) {
            // Update existing day
            let existing = newHistory[index]
            let updated = DailyFunctionality(
                date: existing.date,
                totalFocusedTime: existing.totalFocusedTime + session.totalFocusedTime,
                totalWastedTime: existing.totalWastedTime + session.totalWastedTime,
                sessionsCount: existing.sessionsCount + session.sessionsCount
            )
            newHistory[index] = updated
        } else {
            // Add new day
            newHistory.append(session)
        }
        return newHistory
    }
}
