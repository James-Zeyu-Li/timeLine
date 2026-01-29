import SwiftUI
import TimeLineCore

extension CardDetailEditSheet {
    // MARK: - Logic & Helpers
    
    var libraryBinding: Binding<Bool> {
        Binding(
            get: { libraryStore.entry(for: cardTemplateId) != nil },
            set: { isOn in
                if isOn {
                    // We need the template logic to add.
                    // If draft is valid, update store then add to library
                    saveChanges()
                    if let template = cardStore.get(id: cardTemplateId) {
                        libraryStore.add(templateId: template.id)
                    }
                } else {
                    libraryStore.remove(templateId: cardTemplateId)
                }
                stateManager.requestSave()
            }
        )
    }

    func taskModeLabel(_ mode: TaskMode) -> String {
        switch mode {
        case .focusStrictFixed: return "Focus Fixed"
        case .focusGroupFlexible: return "Focus Flex"
        case .reminderOnly: return "Reminder"
        }
    }
    
    func taskModeTint(_ mode: TaskMode) -> Color {
        switch mode {
        case .focusStrictFixed: return .cyan
        case .focusGroupFlexible: return .mint
        case .reminderOnly: return .orange
        }
    }

    func deadlineLabel(_ option: Int?) -> String {
        guard let option else { return "Off" }
        return "\(option)d"
    }

    var isTaskModeLocked: Bool {
        if case .fighting = engine.state, engine.currentBoss?.templateId == cardTemplateId {
            return true
        }
        return false
    }
    
    func loadCardIfNeeded() {
        guard !didLoad else { return }
        if let card = cardStore.get(id: cardTemplateId) {
            draft = TaskDraft.fromTemplate(card)
            didLoad = true
        } else {
            cardMissing = true
        }
    }
    
    func saveChanges() {
        let isReminder = draft.taskMode == .reminderOnly
        let rule: RepeatRule
        if isReminder {
            rule = .none
        } else {
            switch draft.repeatType {
            case .none: rule = .none
            case .daily: rule = .daily
            case .weekly: rule = .weekly(days: draft.selectedWeekdays)
            case .monthly: rule = .monthly(days: draft.selectedWeekdays)
            }
        }
        
        let template = CardTemplate(
            id: cardTemplateId,
            title: draft.title,
            icon: draft.selectedCategory.icon,
            defaultDuration: draft.duration,
            tags: [],
            energyColor: energyToken(for: draft.selectedCategory),
            category: draft.selectedCategory,
            style: isReminder ? .passive : .focus,
            taskMode: draft.taskMode,
            fixedTime: nil,
            repeatRule: rule,
            remindAt: isReminder ? draft.reminderTime : nil,
            leadTimeMinutes: draft.leadTimeMinutes,
            deadlineWindowDays: isReminder ? nil : draft.deadlineWindowDays
        )
        
        cardStore.update(template)
        updateOccurrences(for: template)
    }
    
    func updateOccurrences(for template: CardTemplate) {
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        for node in daySession.nodes where !node.isCompleted {
            guard case .battle(let boss) = node.type,
                  boss.templateId == template.id else { continue }
            timelineStore.updateNode(id: node.id, payload: template)
        }
    }

    func energyToken(for category: TaskCategory) -> EnergyColorToken {
        switch category {
        case .work, .study: return .focus
        case .gym: return .gym
        case .rest: return .rest
        case .other: return .creative
        }
    }
}
