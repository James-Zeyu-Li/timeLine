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

    
    /// Calculates the current streak of consecutive days with at least one session.
    public static func calculateCurrentStreak(history: [DailyFunctionality]) -> Int {
        // Sort history by date descending (newest first)
        let sortedHistory = history.sorted { $0.date > $1.date }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var streak = 0
        var expectedDate = today
        
        // precise check: if the most recent entry is NOT today, check if it's yesterday.
        // If it's older than yesterday, streak is 0.
        // If it's today, we start counting.
        
        // Optimization: Check the first entry
        guard let first = sortedHistory.first else { return 0 }
        let firstDate = calendar.startOfDay(for: first.date)
        
        if firstDate == today {
            // Good, we have activity today
            expectedDate = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), firstDate == yesterday {
            // No activity today yet, but we have activity yesterday, so streak is arguably alive?
            // Usually "Current Streak" includes today if active, or up to yesterday.
            // If I miss today, streak breaks tomorrow. So today it is still active count from yesterday.
            expectedDate = yesterday
        } else {
            // Last activity was before yesterday. Streak broken.
            return 0
        }
        
        for day in sortedHistory {
            let date = calendar.startOfDay(for: day.date)
            if date == expectedDate {
                streak += 1
                // Next expected date is the day before this one
                if let prevDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) {
                    expectedDate = prevDate
                } else {
                    break // Should not happen
                }
            } else if date > expectedDate {
                // Should not happen in sorted list unless duplicates
                continue
            } else {
                // Gap detected
                break
            }
        }
        
        return streak
    }
    
    /// Calculates the percentage growth of focused time compared to the previous week.
    /// Returns 0 if previous week was 0.
    public static func calculateWeeklyGrowth(currentWeekFocused: TimeInterval, previousWeekFocused: TimeInterval) -> Int {
        if previousWeekFocused == 0 {
            return currentWeekFocused > 0 ? 100 : 0
        }
        let growth = (currentWeekFocused - previousWeekFocused) / previousWeekFocused
        return Int(growth * 100)
    }
}
