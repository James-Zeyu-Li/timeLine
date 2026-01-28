import Foundation
import TimeLineCore

extension CardDetailEditSheet {
    // MARK: - Task Draft Model
    struct TaskDraft: Equatable {
        var title: String
        var selectedCategory: TaskCategory
        var taskMode: TaskMode
        var duration: TimeInterval
        var reminderTime: Date
        var leadTimeMinutes: Int
        var repeatType: RepeatType
        var selectedWeekdays: Set<Int>
        var deadlineWindowDays: Int?
        
        static let `default` = TaskDraft(
            title: "",
            selectedCategory: .work,
            taskMode: .focusStrictFixed,
            duration: 1800,
            reminderTime: Date().addingTimeInterval(3600),
            leadTimeMinutes: 0,
            repeatType: .none,
            selectedWeekdays: [],
            deadlineWindowDays: nil
        )
        
        static func fromTemplate(_ template: CardTemplate) -> TaskDraft {
            var draft = TaskDraft.default
            draft.title = template.title
            draft.selectedCategory = template.category
            draft.taskMode = template.taskMode
            draft.duration = template.defaultDuration
            draft.reminderTime = template.remindAt ?? draft.reminderTime
            draft.leadTimeMinutes = template.leadTimeMinutes
            switch template.repeatRule {
            case .none:
                draft.repeatType = .none
                draft.selectedWeekdays = []
            case .daily:
                draft.repeatType = .daily
                draft.selectedWeekdays = []
            case .weekly(let days):
                draft.repeatType = .weekly
                draft.selectedWeekdays = days
            case .monthly(let days):
                draft.repeatType = .monthly
                draft.selectedWeekdays = days
            }
            draft.deadlineWindowDays = template.deadlineWindowDays
            return draft
        }
    }

    enum RepeatType: String, CaseIterable, Identifiable {
        case none = "None"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        var id: String { rawValue }
    }
}
