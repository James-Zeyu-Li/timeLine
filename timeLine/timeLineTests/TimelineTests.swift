import XCTest
@testable import timeLine // Replace with your App Module Name if different

final class TimelineTests: XCTestCase {
    
    var store: TimelineV2Store!
    var calendar: Calendar!
    var now: Date!
    var startOfToday: Date!
    
    override func setUp() {
        super.setUp()
        calendar = Calendar.current
        now = Date()
        startOfToday = calendar.startOfDay(for: now)
        store = TimelineV2Store()
    }
    
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    
    func testCarryOverTasks() {
        // Given: A task created yesterday that is NOT done
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let task = TimelineTask(title: "Carry Over", createdAt: yesterday, status: .todo)
        
        store.tasks = [task]
        
        // When: Loading Today
        let days = store.loadDays(referenceDate: now)
        let todayTimeline = days.first(where: { Calendar.current.isDateInToday($0.date) })
        
        // Then: It should be in carryOverTasks
        XCTAssertNotNil(todayTimeline)
        XCTAssertTrue(todayTimeline!.carryOverTasks.contains(where: { $0.id == task.id }))
        // And NOT in tasksForDay (Created Today)
        XCTAssertFalse(todayTimeline!.tasksForDay.contains(where: { $0.id == task.id }))
    }
    
    func testTasksCreatedToday() {
        // Given: A task created Today
        let task = TimelineTask(title: "Fresh", createdAt: now, status: .todo)
        store.tasks = [task]
        
        // When: Loading Today
        let days = store.loadDays(referenceDate: now)
        let todayTimeline = days.first(where: { Calendar.current.isDateInToday($0.date) })
        
        // Then
        XCTAssertNotNil(todayTimeline)
        XCTAssertTrue(todayTimeline!.tasksForDay.contains(where: { $0.id == task.id }))
        XCTAssertFalse(todayTimeline!.carryOverTasks.contains(where: { $0.id == task.id }))
    }
    
    func testCompletedTodayRule() {
        // Given: A task created Yesterday but completed Today
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let task = TimelineTask(title: "Done Today", createdAt: yesterday, completedAt: now, status: .done)
        store.tasks = [task]
        
        // When: Loading Today
        let days = store.loadDays(referenceDate: now)
        let todayTimeline = days.first(where: { Calendar.current.isDateInToday($0.date) })
        
        // Then:
        // 1. Not in Carry Over (because it is done)
        XCTAssertFalse(todayTimeline!.carryOverTasks.contains(where: { $0.id == task.id }))
        // 2. Not in Created Today (created yesterday)
        XCTAssertFalse(todayTimeline!.tasksForDay.contains(where: { $0.id == task.id }))
        // 3. IS in Completed Today
        XCTAssertTrue(todayTimeline!.completedTodayTasks.contains(where: { $0.id == task.id }))
    }
    
    func testDayNavigatesCorrectly() {
        // Given: A task for tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let task = TimelineTask(title: "Future", createdAt: tomorrow)
        store.tasks = [task]
        
        // When: Loading Days
        let days = store.loadDays(referenceDate: now)
        
        // Then: Find Tomorrow's Timeline
        let tomorrowTimeline = days.first(where: { calendar.isDate($0.date, inSameDayAs: tomorrow) })
        XCTAssertNotNil(tomorrowTimeline)
        XCTAssertTrue(tomorrowTimeline!.tasksForDay.contains(where: { $0.id == task.id }))
    }
}
