import SwiftUI
import Combine
import TimeLineCore

@MainActor
class PlanViewModel: ObservableObject {

    // MARK: - State
    @Published var draftText: String = ""
    // stagedTemplates removed in favor of direct TimelineStore.inbox usage

    // Derived properties from TimelineStore.inbox
    // Note: We need to filter/sort from the store. 
    // Since TimelineStore doesn't publish changes directly to this VM, 
    // PlanSheetView should observe TimelineStore and pass data, or we rely on the EnvironmentObject in View.
    // However, to keep VM logic clean, we can expose helpers.
    
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
        
        // No draft loading needed - data is in TimelineStore.inbox
    }
    
    // MARK: - Actions
    
    func parseAndAdd(finishBy: FinishBySelection = .next3Days) {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // 1. Parse
        let parsed = QuickEntryParser.parseDetailed(input: trimmed)
        let title = parsed?.template.title ?? trimmed
        let duration = parsed?.template.defaultDuration ?? 25 * 60
        
        // 2. Create Template
        var newTemplate = CardTemplate(
            id: UUID(),
            title: title,
            defaultDuration: duration,
            energyColor: parsed?.template.energyColor ?? .focus,
            style: parsed?.template.style ?? .focus,
            taskMode: .focusStrictFixed,
            isEphemeral: true // Kept as ephemeral until moved to library/timeline? Or straightforward?
        )
        
        // 3. Set deadline logic (Optional, assuming unscheduled nodes might carry this metadata in future or via specific Node properties)
        if let deadline = finishBy.toDate() {
            newTemplate.deadlineAt = deadline
        }
        
        // 4. Add to CardStore & Inbox
        // We must add template to store first so ID resolution works
        guard let cardStore, let timelineStore else {
            draftText = ""
            return
        }
        
        cardStore.add(newTemplate)
        _ = timelineStore.addToInbox(cardTemplateId: newTemplate.id, using: cardStore)
        
        // 5. Reset Input
        draftText = ""
    }
    
    func addQuickAccessTask(_ template: CardTemplate, finishBy: FinishBySelection) {
        // Clone template as ephemeral so we don't modify the library original if we change deadlines
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
        
        guard let cardStore, let timelineStore else { return }
        cardStore.add(newTemplate)
        _ = timelineStore.addToInbox(cardTemplateId: newTemplate.id, using: cardStore)
    }
    
    func handleDrop(items: [String], into timeSlot: FinishBySelection) {
        guard let itemString = items.first else { return }
        if itemString.hasPrefix("TEMPLATE:") {
             let uuidString = String(itemString.dropFirst(9))
             if let uuid = UUID(uuidString: uuidString),
                let template = cardStore?.get(id: uuid) {
                 addQuickAccessTask(template, finishBy: timeSlot)
             }
        }
    }
    
    func deleteInboxItem(id: UUID) {
        timelineStore?.deleteFromInbox(nodeId: id)
    }
    
    func launchExpedition(dismissAction: () -> Void) {
        guard let timelineStore, let daySession else { return }
        
        let inboxItems = daySession.inbox
        guard !inboxItems.isEmpty else { return }
        
        print("[PlanVM] Launching expedition with \(inboxItems.count) items")
        
        // 1. Move all inbox items to timeline
        // Strategy: Process them in order and move them.
        // Since `moveFromInboxToStart` puts them at `currentIndex`, if we iterate reversed we might maintain order,
        // or we iterate forward and they stack.
        // Better strategy usually: insert all at once or one by one.
        // `moveFromInboxToStart` does: remove from inbox -> insert at currentIndex.
        // If we have [A, B, C] in inbox.
        // Move A -> Timeline: [..., A, ...] (Current)
        // Move B -> Timeline: [..., B, A, ...] or [A, B]? 
        // `moveFromInboxToStart` inserts at `currentIndex`.
        // If `currentIndex` stays same, it pushes previous down?
        // Let's check `placeCardOccurrenceAtCurrent` logic or `moveFromInboxToStart` logic.
        // `moveFromInboxToStart` inserts at `currentIndex`.
        // If I do A, then B. Timeline becomes B, then A (if inserting at index).
        // So we should reverse iterate to keep order A, B, C.
        
        for node in inboxItems.reversed() {
            timelineStore.moveFromInboxToStart(nodeId: node.id)
        }
        
        // Validation: Verify items are gone from inbox (should be auto handled by move)
        dismissAction()
    }
    
    // Helpers for View
    func updateTaskDeadline(nodeId: UUID, finishBy: FinishBySelection) {
        // Logic to update deadline on an existing inbox node
        // Requires updating the underlying CardTemplate or specific Node property.
        // Current Inbox Node refers to a CardTemplate.
        // We get the node -> get templateId -> update template?
        // Note: Sharing mutable templates in Inbox is tricky. 
        // For now, assume we just re-save template if it's ephemeral.
        
        guard let node = daySession?.nodes.first(where: { $0.id == nodeId }) ?? daySession?.inbox.first(where: { $0.id == nodeId }),
              case .battle(let boss) = node.type,
              let templateId = boss.templateId,
              var template = cardStore?.get(id: templateId)
        else { return }
        
        if let deadline = finishBy.toDate() {
            template.deadlineAt = deadline
        } else {
            template.deadlineAt = nil
        }
        
        cardStore?.update(template)
        // Trigger UI refresh via objectWillChange if needed, or Store handles it.
    }
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
