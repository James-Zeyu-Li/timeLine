import Foundation

enum TaskStatus: String, Codable {
    case todo
    case done
}

struct TimelineTask: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var createdAt: Date
    var completedAt: Date?
    var status: TaskStatus
    var dueDate: Date?
    
    // Explicit init for mock data creation flexibility
    init(id: UUID = UUID(), title: String, createdAt: Date, completedAt: Date? = nil, status: TaskStatus = .todo, dueDate: Date? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.status = status
        self.dueDate = dueDate
    }
}

struct TimelineDay: Identifiable, Hashable {
    let date: Date // startOfDay
    let tasksForDay: [TimelineTask] // Created today
    let carryOverTasks: [TimelineTask] // Created before today, not done
    let completedTodayTasks: [TimelineTask] // Completed today (regardless of creation)
    
    var id: Date { date }
    
    var isEmpty: Bool {
        tasksForDay.isEmpty && carryOverTasks.isEmpty && completedTodayTasks.isEmpty
    }
}
