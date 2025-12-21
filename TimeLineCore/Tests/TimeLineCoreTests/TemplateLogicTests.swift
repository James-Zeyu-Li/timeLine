import XCTest
@testable import TimeLineCore

final class TemplateLogicTests: XCTestCase {
    
    func testRepeatRuleMatching() {
        let calendar = Calendar.current
        let today = Date() // Let's say today is whatever
        
        // 1. Daily
        let dailyRule = RepeatRule.daily
        XCTAssertTrue(dailyRule.matches(date: today), "Daily should match any day")
        
        // 2. Weekly
        let weekday = calendar.component(.weekday, from: today)
        let weeklyRule = RepeatRule.weekly(days: [weekday])
        XCTAssertTrue(weeklyRule.matches(date: today), "Weekly should match today's weekday")
        
        let subWeekday = (weekday % 7) + 1
        let otherWeeklyRule = RepeatRule.weekly(days: [subWeekday])
        XCTAssertFalse(otherWeeklyRule.matches(date: today), "Weekly should NOT match other weekday")
        
        // 3. Monthly
        let day = calendar.component(.day, from: today)
        let monthlyRule = RepeatRule.monthly(days: [day])
        XCTAssertTrue(monthlyRule.matches(date: today), "Monthly should match today's day")
        
        let otherMonthlyRule = RepeatRule.monthly(days: [day + 1])
        XCTAssertFalse(otherMonthlyRule.matches(date: today), "Monthly should NOT match other day")
    }
    
    func testSpawnLogic() {
        let template = TaskTemplate(
            title: "Test Task",
            style: .focus,
            duration: 3600,
            repeatRule: .none,
            category: .work
        )
        
        let boss = TemplateManager.spawn(from: template)
        
        XCTAssertEqual(boss.name, "Test Task")
        XCTAssertEqual(boss.maxHp, 3600)
        XCTAssertEqual(boss.style, .focus)
        XCTAssertEqual(boss.templateId, template.id)
    }
    
    func testProcessRepeats() {
        let matchingTemplate = TaskTemplate(
            title: "Daily Gym",
            repeatRule: .daily
        )
        
        // Create a rule that won't match (e.g. weekly on a different day)
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let otherWeekday = (weekday % 7) + 1
        let nonMatchingTemplate = TaskTemplate(
            title: "Weekly Meeting",
            repeatRule: .weekly(days: [otherWeekday])
        )
        
        let templates = [matchingTemplate, nonMatchingTemplate]
        
        let tasks = TemplateManager.processRepeats(templates: templates, for: today)
        
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.name, "Daily Gym")
    }
}
