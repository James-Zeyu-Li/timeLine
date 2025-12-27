import XCTest
@testable import TimeLineCore

final class SpawnLogicTests: XCTestCase {
    
    // MARK: - Helpers
    func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.calendar = Calendar.current
        return Calendar.current.date(from: components)!
    }
    
    // MARK: - Tests
    
    func testDailySpawn() {
        let template = CardTemplate(id: UUID(), title: "Daily Task", repeatRule: .daily)
        let today = date(year: 2025, month: 1, day: 1)
        var ledger: Set<String> = []
        
        // 1. First Spawn
        let (tasks, newKeys) = SpawnManager.processRepeats(
            templates: [template],
            for: today,
            ledger: ledger
        )
        
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.name, "Daily Task")
        XCTAssertEqual(newKeys.count, 1)
        
        // Update ledger
        newKeys.forEach { ledger.insert($0) }
        
        // 2. Second Spawn (Should be empty)
        let (tasks2, newKeys2) = SpawnManager.processRepeats(
            templates: [template],
            for: today,
            ledger: ledger
        )
        
        XCTAssertTrue(tasks2.isEmpty)
        XCTAssertTrue(newKeys2.isEmpty)
    }
    
    func testWeeklySpawn() {
        // Create a Monday task (2 = Monday in Gregorian)
        // Note: Set<Int> for weekdays
        let template = CardTemplate(id: UUID(), title: "Monday Task", repeatRule: .weekly(days: [2]))
        
        // Test on a Monday (Jan 6, 2025 is a Monday)
        let monday = date(year: 2025, month: 1, day: 6)
        let (tasksMonday, _) = SpawnManager.processRepeats(
            templates: [template],
            for: monday,
            ledger: []
        )
        XCTAssertEqual(tasksMonday.count, 1, "Should spawn on Monday")
        
        // Test on a Tuesday (Jan 7, 2025)
        let tuesday = date(year: 2025, month: 1, day: 7)
        let (tasksTuesday, _) = SpawnManager.processRepeats(
            templates: [template],
            for: tuesday,
            ledger: []
        )
        XCTAssertTrue(tasksTuesday.isEmpty, "Should NOT spawn on Tuesday")
    }
    
    func testLedgerKeyFormat() {
        let id = UUID()
        let template = CardTemplate(id: id, title: "Test", repeatRule: .daily)
        let day = date(year: 2025, month: 5, day: 20)
        
        let (_, newKeys) = SpawnManager.processRepeats(
            templates: [template],
            for: day,
            ledger: []
        )
        
        let expectedKey = "\(id.uuidString)_2025-05-20"
        XCTAssertEqual(newKeys.first, expectedKey)
    }
}
