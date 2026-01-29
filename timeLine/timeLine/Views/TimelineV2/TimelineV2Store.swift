import SwiftUI
import Combine

class TimelineV2Store: ObservableObject {
    @Published var tasks: [TimelineTask] = []
    
    // Configurable range
    private let pastDaysToCheck = 14
    private let futureDaysToCheck = 7
    
    init(tasks: [TimelineTask] = []) {
        self.tasks = tasks
    }
    
    // MARK: - API
    
    /// Returns TimelineDay objects for the configured range relative to referenceDate (default: today)
    func loadDays(referenceDate: Date = Date()) -> [TimelineDay] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        
        var days: [TimelineDay] = []
        
        // Generate dates from -past to +future
        for offset in -pastDaysToCheck...futureDaysToCheck {
            if let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) {
                let day = buildTimelineDay(for: date)
                days.append(day)
            }
        }
        
        return days
    }
    
    /// Efficiently builds a single TimelineDay
    func buildTimelineDay(for date: Date) -> TimelineDay {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return TimelineDay(date: date, tasksForDay: [], carryOverTasks: [], completedTodayTasks: [])
        }
        
        // 1. Carry Over: Status != done AND Created < StartOfDay
        // Note: For performance with large datasets, this filters would be optimized/indexed.
        // Keeping straightforward for "KISS" requirement.
        let carryOver = tasks.filter { task in
            task.status != .done && task.createdAt < startOfDay
        }
        
        // 2. Created Today: Created in [Start, End)
        let createdToday = tasks.filter { task in
            task.createdAt >= startOfDay && task.createdAt < endOfDay
        }
        
        // 3. Completed Today: Completed in [Start, End)
        let completedToday = tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= startOfDay && completedAt < endOfDay
        }
        
        return TimelineDay(
            date: startOfDay,
            tasksForDay: createdToday,
            carryOverTasks: carryOver,
            completedTodayTasks: completedToday
        )
    }
    
    // MARK: - Actions
    
    func updateTask(_ task: TimelineTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
    }
    
    func delete(_ task: TimelineTask) {
        tasks.removeAll { $0.id == task.id }
    }
    
    /// Toggles task status. If marking done, sets completedAt to Now. If undoing, removes completedAt.
    func toggleCompletion(_ task: TimelineTask) {
        var updated = task
        if updated.status == .todo {
            updated.status = .done
            updated.completedAt = Date()
        } else {
            updated.status = .todo
            updated.completedAt = nil
        }
        updateTask(updated)
    }
}
