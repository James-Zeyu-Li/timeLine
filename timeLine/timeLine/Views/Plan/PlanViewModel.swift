import SwiftUI
import Combine
import TimeLineCore

@MainActor
class PlanViewModel: ObservableObject {
    // MARK: - Dependencies
    private var timelineStore: TimelineStore?
    private var cardStore: CardTemplateStore?
    
    // MARK: - State
    @Published var draftText: String = ""
    @Published var stagedTemplates: [StagedTask] = [] // Transient staging with date info
    @Published var recentTasks: [CardTemplate] = []
    
    // MARK: - Configuration
    func configure(timelineStore: TimelineStore, cardStore: CardTemplateStore) {
        self.timelineStore = timelineStore
        self.cardStore = cardStore
        loadRecentTasks()
    }
    
    // MARK: - Actions
    
    func parseAndStage(finishBy: FinishBySelection = .next3Days) {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // 1. Parse
        let parsed = QuickEntryParser.parseDetailed(input: trimmed)
        let title = parsed?.template.title ?? trimmed
        let duration = parsed?.template.defaultDuration ?? 25 * 60
        
        // 2. Create Ephemeral Template
        var newTemplate = CardTemplate(
            id: UUID(),
            title: title,
            defaultDuration: duration,
            energyColor: parsed?.template.energyColor ?? .focus,
            style: parsed?.template.style ?? .focus,
            taskMode: .focusStrictFixed,
            isEphemeral: true
        )
        
        // 3. Set deadline based on finishBy selection
        if let deadline = finishBy.toDate() {
            newTemplate.deadlineAt = deadline
        }
        
        // 4. Create staged task
        let stagedTask = StagedTask(template: newTemplate, finishBy: finishBy)
        
        // 5. Stage
        withAnimation {
            stagedTemplates.append(stagedTask)
        }
        
        // 6. Reset Input
        draftText = ""
    }
    
    func stageQuickAccessTask(_ template: CardTemplate, finishBy: FinishBySelection = .next3Days) {
        var newTemplate = CardTemplate(
            id: UUID(),
            title: template.title,
            defaultDuration: template.defaultDuration,
            energyColor: template.energyColor,
            taskMode: template.taskMode,
            isEphemeral: true
        )
        
        // Set deadline based on finishBy selection
        if let deadline = finishBy.toDate() {
            newTemplate.deadlineAt = deadline
        }
        
        let stagedTask = StagedTask(template: newTemplate, finishBy: finishBy)
        
        withAnimation {
            stagedTemplates.append(stagedTask)
        }
    }
    
    func removeStagedTask(id: UUID) {
        withAnimation {
            stagedTemplates.removeAll { $0.id == id }
        }
    }
    
    func updateTaskFinishBy(id: UUID, finishBy: FinishBySelection) {
        guard let index = stagedTemplates.firstIndex(where: { $0.id == id }) else { return }
        
        var updatedTask = stagedTemplates[index]
        updatedTask.finishBy = finishBy
        
        // Update template deadline
        if let deadline = finishBy.toDate() {
            updatedTask.template.deadlineAt = deadline
        } else {
            updatedTask.template.deadlineAt = nil
        }
        
        stagedTemplates[index] = updatedTask
    }
    
    // Group staged tasks by finish date
    var groupedTasks: [TaskGroup] {
        // Step 1: Group tasks by their groupKey
        let groupedDict = Dictionary(grouping: stagedTemplates) { task in
            task.finishBy.groupKey
        }
        
        // Step 2: Convert to TaskGroup array
        let taskGroups = groupedDict.map { (key, tasks) in
            let sortedTasks = tasks.sorted { $0.template.title < $1.template.title }
            return TaskGroup(
                title: key.displayName,
                tasks: sortedTasks,
                sortOrder: key.sortOrder
            )
        }
        
        // Step 3: Sort groups by sortOrder
        return taskGroups.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func commitToTimeline(dismissAction: () -> Void) {
        guard let timelineStore, let cardStore, !stagedTemplates.isEmpty else { return }
        
        // Batch add to timeline
        for stagedTask in stagedTemplates {
            // Must add template to store first so ID lookup works
            cardStore.add(stagedTask.template)
            
            // Add to inbox for now - user can organize later
            _ = timelineStore.addToInbox(cardTemplateId: stagedTask.template.id, using: cardStore)
        }
        
        stagedTemplates.removeAll()
        dismissAction()
    }
    
    // MARK: - Private
    private func loadRecentTasks() {
        recentTasks = [
            CardTemplate.mock(title: "Coding", duration: 45 * 60, color: .focus),
            CardTemplate.mock(title: "Reading", duration: 30 * 60, color: .creative),
            CardTemplate.mock(title: "Deep Work", duration: 60 * 60, color: .focus)
        ]
    }
}

// MARK: - Supporting Types

struct StagedTask: Identifiable, Equatable {
    let id = UUID()
    var template: CardTemplate
    var finishBy: FinishBySelection
    
    static func == (lhs: StagedTask, rhs: StagedTask) -> Bool {
        lhs.id == rhs.id
    }
}

struct TaskGroup: Identifiable {
    let id = UUID()
    let title: String
    let tasks: [StagedTask]
    let sortOrder: Int
}

enum FinishBySelection: Equatable, CaseIterable {
    case tonight
    case tomorrow
    case next3Days
    case thisWeek
    case none
    case pickDate(Date)
    
    static var allCases: [FinishBySelection] {
        [.tonight, .tomorrow, .next3Days, .thisWeek, .none]
    }
    
    var displayName: String {
        switch self {
        case .tonight:
            return "今晚"
        case .tomorrow:
            return "明天"
        case .next3Days:
            return "未来3天"
        case .thisWeek:
            return "本周内"
        case .none:
            return "无截止"
        case .pickDate(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    var iconName: String {
        switch self {
        case .tonight:
            return "moon.stars.fill"
        case .tomorrow:
            return "sun.max.fill"
        case .next3Days:
            return "calendar.badge.clock"
        case .thisWeek:
            return "calendar"
        case .none:
            return "infinity"
        case .pickDate:
            return "calendar.circle"
        }
    }
    
    var groupKey: GroupKey {
        switch self {
        case .tonight:
            return .tonight
        case .tomorrow:
            return .tomorrow
        case .next3Days:
            return .next3Days
        case .thisWeek:
            return .thisWeek
        case .none:
            return .none
        case .pickDate(let date):
            return .customDate(date)
        }
    }
    
    func toDate() -> Date? {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .tonight:
            return endOfDay(for: now)
        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
            return endOfDay(for: tomorrow)
        case .next3Days:
            guard let next3Days = calendar.date(byAdding: .day, value: 3, to: now) else { return nil }
            return endOfDay(for: next3Days)
        case .thisWeek:
            guard let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end else { return nil }
            return endOfWeek
        case .none:
            return nil
        case .pickDate(let date):
            return endOfDay(for: date)
        }
    }
    
    private func endOfDay(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .day, for: date)?.end ?? date
    }
}

enum GroupKey: Equatable, Hashable {
    case tonight
    case tomorrow
    case next3Days
    case thisWeek
    case none
    case customDate(Date)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .tonight:
            hasher.combine("tonight")
        case .tomorrow:
            hasher.combine("tomorrow")
        case .next3Days:
            hasher.combine("next3Days")
        case .thisWeek:
            hasher.combine("thisWeek")
        case .none:
            hasher.combine("none")
        case .customDate(let date):
            hasher.combine("customDate")
            hasher.combine(date)
        }
    }
    
    var displayName: String {
        switch self {
        case .tonight:
            return "今晚"
        case .tomorrow:
            return "明天"
        case .next3Days:
            return "未来3天"
        case .thisWeek:
            return "本周内"
        case .none:
            return "无截止"
        case .customDate(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .tonight:
            return 0
        case .tomorrow:
            return 1
        case .next3Days:
            return 2
        case .thisWeek:
            return 3
        case .customDate:
            return 4
        case .none:
            return 5
        }
    }
}

// Local Extension for Mocking
extension CardTemplate {
    static func mock(title: String, duration: TimeInterval, color: EnergyColorToken) -> CardTemplate {
        CardTemplate(
            title: title,
            defaultDuration: duration,
            energyColor: color,
            taskMode: .focusStrictFixed
        )
    }
}
