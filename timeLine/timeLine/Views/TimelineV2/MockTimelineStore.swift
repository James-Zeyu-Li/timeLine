import Foundation

class MockTimelineStore: TimelineV2Store {
    init() {
        let now = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        var mockTasks: [TimelineTask] = []
        
        // 1. Unfinished Carry Over (Created Yesterday)
        mockTasks.append(TimelineTask(
            title: "Old Lingering Task (Yesterday)",
            createdAt: yesterdayStart.addingTimeInterval(3600), // Yesterday 1AM
            status: .todo
        ))
        
        // 2. Finished Carry Over (Created Yesterday, Completed Yesterday) -> Should appear in Yesterday's "Completed"
        mockTasks.append(TimelineTask(
            title: "Finished Yesterday",
            createdAt: yesterdayStart.addingTimeInterval(7200),
            completedAt: yesterdayStart.addingTimeInterval(15000),
            status: .done
        ))
        
        // 3. Finished Carry Over (Created Yesterday, Completed TODAY) -> Should appear in Today's "Completed"
        mockTasks.append(TimelineTask(
            title: "Long Running Task (Done Today)",
            createdAt: yesterdayStart.addingTimeInterval(4000),
            completedAt: todayStart.addingTimeInterval(3600), // Today 1AM
            status: .done
        ))
        
        // 4. Created Today, Active
        mockTasks.append(TimelineTask(
            title: "Fresh Task for Today",
            createdAt: todayStart.addingTimeInterval(4000),
            status: .todo
        ))
        
        // 5. Created Today, Completed Today
        mockTasks.append(TimelineTask(
            title: "Quick Win (Today)",
            createdAt: todayStart.addingTimeInterval(5000),
            completedAt: todayStart.addingTimeInterval(6000),
            status: .done
        ))
        
        // 6. Future Task
        mockTasks.append(TimelineTask(
            title: "Prepare for Tomorrow",
            createdAt: tomorrowStart.addingTimeInterval(3600),
            status: .todo
        ))

        super.init(tasks: mockTasks)
    }
}
