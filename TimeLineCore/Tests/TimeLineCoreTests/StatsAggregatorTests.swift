import XCTest
@testable import TimeLineCore

final class StatsAggregatorTests: XCTestCase {
    
    // MARK: - Streak Logic Tests
    
    func testCalculateCurrentStreak_singleDay() {
        let history = [
            DailyFunctionality(date: Date(), totalFocusedTime: 60, totalWastedTime: 0, sessionsCount: 1)
        ]
        let streak = StatsAggregator.calculateCurrentStreak(history: history)
        XCTAssertEqual(streak, 1)
    }
    
    func testCalculateCurrentStreak_threeDays() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        
        let history = [
            DailyFunctionality(date: today, totalFocusedTime: 10, totalWastedTime: 0, sessionsCount: 1),
            DailyFunctionality(date: yesterday, totalFocusedTime: 10, totalWastedTime: 0, sessionsCount: 1),
            DailyFunctionality(date: twoDaysAgo, totalFocusedTime: 10, totalWastedTime: 0, sessionsCount: 1)
        ]
        
        let streak = StatsAggregator.calculateCurrentStreak(history: history)
        XCTAssertEqual(streak, 3)
    }
    
    func testCalculateCurrentStreak_brokenStreak() {
        // Today active, yesterday missed, 2 days ago active
        let today = Date()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        
        let history = [
            DailyFunctionality(date: today, totalFocusedTime: 10, totalWastedTime: 0, sessionsCount: 1),
            DailyFunctionality(date: twoDaysAgo, totalFocusedTime: 10, totalWastedTime: 0, sessionsCount: 1)
        ]
        
        let streak = StatsAggregator.calculateCurrentStreak(history: history)
        XCTAssertEqual(streak, 1) // Only today counts
    }
    
    func testCalculateCurrentStreak_yesterdayActiveTodayInactive() {
        // "Current Streak" usually counts if you're still within the window (haven't missed today yet)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        let history = [
            DailyFunctionality(date: yesterday, totalFocusedTime: 10, totalWastedTime: 0, sessionsCount: 1)
        ]
        
        let streak = StatsAggregator.calculateCurrentStreak(history: history)
        XCTAssertEqual(streak, 1) // Streak is 1 because we haven't broken it yet today
    }
    
    func testCalculateCurrentStreak_empty() {
        XCTAssertEqual(StatsAggregator.calculateCurrentStreak(history: []), 0)
    }
    
    // MARK: - Weekly Growth Tests
    
    func testCalculateWeeklyGrowth_positive() {
        // 100m vs 50m = +100%
        let growth = StatsAggregator.calculateWeeklyGrowth(currentWeekFocused: 100, previousWeekFocused: 50)
        XCTAssertEqual(growth, 100)
    }
    
    func testCalculateWeeklyGrowth_negative() {
        // 50m vs 100m = -50%
        let growth = StatsAggregator.calculateWeeklyGrowth(currentWeekFocused: 50, previousWeekFocused: 100)
        XCTAssertEqual(growth, -50)
    }
    
    func testCalculateWeeklyGrowth_zeroPrevious() {
        // 10m vs 0m = 100% (or defined as max growth)
        let growth = StatsAggregator.calculateWeeklyGrowth(currentWeekFocused: 10, previousWeekFocused: 0)
        XCTAssertEqual(growth, 100)
    }
    
    func testCalculateWeeklyGrowth_zeroCurrent() {
        // 0m vs 100m = -100%
        let growth = StatsAggregator.calculateWeeklyGrowth(currentWeekFocused: 0, previousWeekFocused: 100)
        XCTAssertEqual(growth, -100)
    }
    
    func testCalculateWeeklyGrowth_bothZero() {
        let growth = StatsAggregator.calculateWeeklyGrowth(currentWeekFocused: 0, previousWeekFocused: 0)
        XCTAssertEqual(growth, 0)
    }
}
