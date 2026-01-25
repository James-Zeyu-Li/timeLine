import SwiftUI
import Combine
import TimeLineCore

@MainActor
class PlanViewModel: ObservableObject {

    
    // MARK: - State
    @Published var draftText: String = ""
    @Published var stagedTemplates: [StagedTask] = [] // Transient staging with date info
    
    var stagedMorningTasks: [StagedTask] {
        stagedTemplates.filter { $0.finishBy == .tonight } // Keeping 'tonight' as Morning key for now to minimize refactor
    }
    
    var stagedAfternoonTasks: [StagedTask] {
        stagedTemplates.filter { $0.finishBy == .tomorrow } // Keeping 'tomorrow' as Afternoon key
    }
    
    var stagedEveningTasks: [StagedTask] {
        stagedTemplates.filter { $0.finishBy == .next3Days } // Using 'next3Days' as Evening key
    }
    
    var hasStagedTasks: Bool {
        !stagedTemplates.isEmpty
    }
    
    var formattedTotalDuration: String {
        let totalSeconds = stagedTemplates.reduce(0) { $0 + $1.template.defaultDuration }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // Dependencies
    private var timelineStore: TimelineStore?
    private var cardStore: CardTemplateStore?
    private var daySession: DaySession?
    private var engine: BattleEngine?
    private var stateManager: AppStateManager?
    
    // MARK: - Configuration
    func configure(
        timelineStore: TimelineStore,
        cardStore: CardTemplateStore,
        daySession: DaySession,
        engine: BattleEngine,
        stateManager: AppStateManager
    ) {
        self.timelineStore = timelineStore
        self.cardStore = cardStore
        self.daySession = daySession
        self.engine = engine
        self.stateManager = stateManager
        
        // Load Draft
        if !stateManager.planningDraft.isEmpty {
            self.stagedTemplates = stateManager.planningDraft
        }
        // Initial Load

    }
    
    // MARK: - Persistence
    private func saveDraft() {
        stateManager?.planningDraft = stagedTemplates
        stateManager?.requestSave()
    }

    // MARK: - Actions
    
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
        saveDraft()
    }
    
    func stageQuickAccessTask(_ template: CardTemplate, finishBy: FinishBySelection) {
        var newTemplate = CardTemplate(
            id: UUID(),
            title: template.title,
            defaultDuration: template.defaultDuration,
            energyColor: template.energyColor,
            taskMode: template.taskMode,
            isEphemeral: true
        )
        
        if let deadline = finishBy.toDate() {
            newTemplate.deadlineAt = deadline
        }
        
        let stagedTask = StagedTask(template: newTemplate, finishBy: finishBy)
        withAnimation {
            stagedTemplates.append(stagedTask)
        }
        saveDraft()
    }
    
    func handleDrop(items: [String], into timeSlot: FinishBySelection) {
        guard let itemString = items.first else { return }
        if itemString.hasPrefix("TEMPLATE:") {
             let uuidString = String(itemString.dropFirst(9))
             // Need to access cardStore synchronously here, assumption is it's configured
             if let uuid = UUID(uuidString: uuidString),
                let template = cardStore?.get(id: uuid) {
                 stageQuickAccessTask(template, finishBy: timeSlot)
             }
        }
    }
    
    func removeStagedTask(id: UUID) {
        withAnimation {
            stagedTemplates.removeAll { $0.id == id }
        }
        saveDraft()
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
        saveDraft()
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
        guard let timelineStore, let cardStore, let daySession, let engine, !stagedTemplates.isEmpty else {
            print("[PlanVM] commitToTimeline guard failed - stores: \(timelineStore != nil), \(cardStore != nil), \(daySession != nil), \(engine != nil), staged: \(stagedTemplates.count)")
            return
        }
        
        print("[PlanVM] Committing \(stagedTemplates.count) tasks to timeline")
        
        // Step 1: Group staged tasks by Habitat (finishBy)
        let habitatGroups = Dictionary(grouping: stagedTemplates) { $0.finishBy.groupKey }
        
        // Step 2: Sort groups by their natural order (morning first, then afternoon, etc.)
        let sortedGroupKeys = Array(habitatGroups.keys).sorted { (a, b) in
            return a.sortOrder < b.sortOrder
        }
        
        print("[PlanVM] Found \(sortedGroupKeys.count) habitat groups")
        
        var currentAnchorId = daySession.nodes.last?.id
        print("[PlanVM] Initial anchor: \(currentAnchorId?.uuidString ?? "nil (empty timeline)")")
        
        for groupKey in sortedGroupKeys {
            guard let tasksInHabitat = habitatGroups[groupKey] else { continue }
            
            print("[PlanVM] Processing habitat '\(groupKey.displayName)' with \(tasksInHabitat.count) tasks")
            
            // Add all templates to the card store first
            for stagedTask in tasksInHabitat {
                cardStore.add(stagedTask.template)
            }
            
            let templateIds = tasksInHabitat.map { $0.template.id }
            
            if templateIds.count > 1 {
                // Multiple tasks in this Habitat → Create a FocusGroup
                if let anchor = currentAnchorId {
                    if let newId = timelineStore.placeFocusGroupOccurrence(
                        memberTemplateIds: templateIds,
                        anchorNodeId: anchor,
                        placement: .after,
                        using: cardStore
                    ) {
                        currentAnchorId = newId
                        print("[PlanVM] Placed FocusGroup after anchor, new ID: \(newId)")
                    } else {
                        print("[PlanVM] ERROR: placeFocusGroupOccurrence returned nil")
                    }
                } else {
                    // Timeline is empty
                    if let newId = timelineStore.placeFocusGroupOccurrenceAtStart(
                        memberTemplateIds: templateIds,
                        using: cardStore,
                        engine: engine
                    ) {
                        currentAnchorId = newId
                        print("[PlanVM] Placed FocusGroup at start, new ID: \(newId)")
                    } else {
                        print("[PlanVM] ERROR: placeFocusGroupOccurrenceAtStart returned nil")
                    }
                }
            } else if let singleTask = tasksInHabitat.first {
                // Single task → Place individually (no FocusGroup needed)
                if let anchor = currentAnchorId {
                    if let newId = timelineStore.placeCardOccurrence(
                        cardTemplateId: singleTask.template.id,
                        anchorNodeId: anchor,
                        placement: .after,
                        using: cardStore
                    ) {
                        currentAnchorId = newId
                        print("[PlanVM] Placed single task '\(singleTask.template.title)' after anchor, new ID: \(newId)")
                    } else {
                        print("[PlanVM] ERROR: placeCardOccurrence returned nil for '\(singleTask.template.title)'")
                    }
                } else {
                    if let newId = timelineStore.placeCardOccurrenceAtStart(
                        cardTemplateId: singleTask.template.id,
                        using: cardStore,
                        engine: engine
                    ) {
                        currentAnchorId = newId
                        print("[PlanVM] Placed single task '\(singleTask.template.title)' at start, new ID: \(newId)")
                    } else {
                        print("[PlanVM] ERROR: placeCardOccurrenceAtStart returned nil")
                    }
                }
            }
        }
        
        print("[PlanVM] Commit complete. Final node count: \(daySession.nodes.count)")
        stagedTemplates.removeAll()
        saveDraft()
        dismissAction()
    }
    
    // MARK: - Private
// Recent tasks loading removed (was mock data)
}

// MARK: - Supporting Types

// StagedTask moved to TimeLineCore

struct TaskGroup: Identifiable {
    let id = UUID()
    let title: String
    let tasks: [StagedTask]
    let sortOrder: Int
}

// FinishBySelection and GroupKey moved to TimeLineCore

// Local Extension for Mocking
// Mock extension removed
