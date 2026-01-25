import Foundation
import Combine
import UIKit
import TimeLineCore

@MainActor
class MapViewModel: ObservableObject {
    // Dependencies
    private var engine: BattleEngine?
    private var daySession: DaySession?
    private var stateManager: AppStateManager?
    private var cardStore: CardTemplateStore?
    private var use24HourClock: Bool
    
    // Published State for UI
    @Published var banner: BannerData?
    @Published var pulseNextNodeId: UUID?
    @Published var magicInputText: String = ""
    
    // MARK: - Magic Input Handler
    func handleMagicInput() {
        let trimmed = magicInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Parse input using QuickEntryParser
        let parsed = QuickEntryParser.parseDetailed(input: trimmed)
        let title = parsed?.template.title ?? trimmed
        let duration = parsed?.template.defaultDuration ?? 25 * 60
        
        // Create ephemeral template
        let newTemplate = CardTemplate(
            id: UUID(),
            title: title,
            defaultDuration: duration,
            energyColor: parsed?.template.energyColor ?? .focus,
            style: parsed?.template.style ?? .focus,
            taskMode: .focusStrictFixed, // Default to strict for single tasks
            remindAt: nil, // Handle suggested time separately
            isEphemeral: true // Mark as ephemeral (ad-hoc)
        )
        
        // If parsed.suggestedTime (DateComponents) is present, we might want to convert to Date.
        // QuickEntryParser returns DateComponents. CardTemplate.remindAt is Date?.
        // For simplicity, we can let addInboxItem handle placement strategies. 
        // If the parser detected "tonight", it set suggestedTime.
        // We'll update addInboxItem or handle it here.
        // Actually, let's create a Helper to convert components to next occurrence?
        // But CardTemplate expects a specific Date for remindAt.
        // Let's rely on addInboxItem's placement logic for now, or if parser gave specific time, use it.
        // QuickEntryParser result has `suggestedTime: DateComponents?`.
        
        var templateToAdd = newTemplate
        if let components = parsed?.suggestedTime {
             let calendar = Calendar.current
             let now = Date()
             let date = calendar.date(bySettingHour: components.hour ?? 20, minute: components.minute ?? 0, second: 0, of: now)
             if let d = date, d < now {
                 // If time passed today, move to tomorrow? Or keep today for history?
                 // "Tonight" usually implies upcoming.
                 // Let's assume user inputs valid future time or accepts immediate past.
                 // For now, simple binding.
             }
             templateToAdd.fixedTime = components // CardTemplate has fixedTime: DateComponents?
        }
        
        addInboxItem(templateToAdd)
        magicInputText = ""
        
        Haptics.impact(.medium)
    }
    
    private var pulseClearTask: DispatchWorkItem?
    private let allowsPulseClear: Bool
    
    init(use24HourClock: Bool = true, allowsPulseClear: Bool = true) {
        self.use24HourClock = use24HourClock
        self.allowsPulseClear = allowsPulseClear
    }

    func stop() {
        pulseClearTask?.cancel()
        pulseClearTask = nil
    }

    deinit {
        pulseClearTask?.cancel()
    }
    
    func bind(
        engine: BattleEngine,
        daySession: DaySession,
        stateManager: AppStateManager,
        cardStore: CardTemplateStore,
        use24HourClock: Bool
    ) {
        self.engine = engine
        self.daySession = daySession
        self.stateManager = stateManager
        self.cardStore = cardStore
        self.use24HourClock = use24HourClock
    }
    
    func bind(
        engine: BattleEngine,
        daySession: DaySession,
        use24HourClock: Bool
    ) {
        self.engine = engine
        self.daySession = daySession
        self.stateManager = nil
        self.cardStore = nil
        self.use24HourClock = use24HourClock
    }
    
    // MARK: - Update Preferences
    func updatePreferences(use24HourClock: Bool) {
        self.use24HourClock = use24HourClock
    }
    
    // MARK: - Inbox Management
    func addInboxItem(_ item: CardTemplate) {
        guard let daySession, let stateManager, let cardStore, let engine else { return }
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        
        if let remindAt = item.remindAt {
            _ = timelineStore.placeCardOccurrenceByTime(
                cardTemplateId: item.id,
                remindAt: remindAt,
                using: cardStore,
                engine: engine
            )
        } else if let anchorId = daySession.nodes.last?.id {
            _ = timelineStore.placeCardOccurrence(
                cardTemplateId: item.id,
                anchorNodeId: anchorId,
                using: cardStore
            )
        } else {
            _ = timelineStore.placeCardOccurrenceAtStart(
                cardTemplateId: item.id,
                using: cardStore,
                engine: engine
            )
        }
        
        removeInboxItem(item.id)
    }
    
    func removeInboxItem(_ itemId: UUID) {
        guard let stateManager else { return }
        stateManager.inbox.removeAll { $0 == itemId }
        stateManager.requestSave()
    }
    
    // MARK: - Node Operations
    
    func moveNode(from source: IndexSet, to destination: Int) {
        guard let daySession, let stateManager else { return }
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.moveNode(from: source, to: destination)
    }
    
    // MARK: - Time Calculations
    func estimatedStartTime(for node: TimelineNode, upcomingNodes: [TimelineNode]) -> (absolute: String, relative: String?)? {
        guard let daySession else { return nil }
        if case .battle(let boss) = node.type,
           let remindAt = boss.remindAt {
            let absolute = TimeFormatter.formatClock(remindAt, use24Hour: use24HourClock)
            let delta = remindAt.timeIntervalSince(Date())
            let relative = formatRelativeTime(delta)
            return (absolute, relative)
        }
        if let recommended = recommendedStartDate(for: node) {
            let absolute = TimeFormatter.formatClock(recommended, use24Hour: use24HourClock)
            let delta = recommended.timeIntervalSince(Date())
            let relative = formatRelativeTime(delta)
            return (absolute, relative)
        }
        
        guard let idx = upcomingNodes.firstIndex(where: { $0.id == node.id }) else { return nil }
        
        var secondsAhead: TimeInterval = 0
        
        // If there is an active current node, account for remaining time
        if let current = daySession.currentNode, let currentIndex = upcomingNodes.firstIndex(where: { $0.id == current.id }) {
            if currentIndex < idx {
                let currentNodeRemaining = calculateRemainingTime(for: current)
                secondsAhead += currentNodeRemaining
            }
        }
        
        // Sum durations of nodes strictly before this one
        for i in 0..<idx {
            let n = upcomingNodes[i]
            if let current = daySession.currentNode, n.id == current.id {
                continue
            }
            secondsAhead += duration(for: n)
        }
        
        let startDate = Date().addingTimeInterval(secondsAhead)
        let absolute = TimeFormatter.formatClock(startDate, use24Hour: use24HourClock)
        let relative = formatRelativeTime(secondsAhead)
        return (absolute, relative)
    }
    
    private func calculateRemainingTime(for node: TimelineNode) -> TimeInterval {
        if let daySession,
           let engine,
           let current = daySession.currentNode,
           current.id == node.id,
           let remaining = engine.remainingTime {
            return remaining
        }
        
        switch node.type {
        case .battle(let boss):
            return boss.maxHp
        case .bonfire(let dur):
            return dur
        case .treasure:
            return 0
        }
    }
    
    private func duration(for node: TimelineNode) -> TimeInterval {
        switch node.type {
        case .battle(let boss): return boss.maxHp
        case .bonfire(let dur): return dur
        case .treasure: return 0
        }
    }
    
    private func recommendedStartDate(for node: TimelineNode) -> Date? {
        guard case .battle(let boss) = node.type, let components = boss.recommendedStart else {
            return nil
        }
        
        let calendar = Calendar.current
        var resolved = components
        let now = Date()
        resolved.calendar = calendar
        resolved.year = calendar.component(.year, from: now)
        resolved.month = calendar.component(.month, from: now)
        resolved.day = calendar.component(.day, from: now)
        return calendar.date(from: resolved)
    }
    
    private func formatRelativeTime(_ secondsAhead: TimeInterval) -> String? {
        CountdownFormatter.formatRelative(seconds: secondsAhead)
    }
    
    // MARK: - Event Handling
    func handleUIEvent(_ event: TimelineUIEvent) {
        guard let daySession else { return }
        let resolved = resolveUpNext(after: daySession.currentNode)
        switch event {
        case .victory(_, _):
            pulseNext(nodeId: resolved.nodeId)
        case .retreat(_, let wastedMinutes):
            banner = BannerData(kind: .distraction(wastedMinutes: wastedMinutes), upNextTitle: resolved.title)
            pulseNextNodeId = resolved.nodeId
            schedulePulseClear()
        case .incompleteExit(_, let focusedSeconds, let remainingSeconds):
            banner = BannerData(
                kind: .incompleteExit(
                    focusedSeconds: focusedSeconds,
                    remainingSeconds: remainingSeconds
                ),
                upNextTitle: resolved.title
            )
            pulseNextNodeId = resolved.nodeId
            schedulePulseClear()
        case .completedExploration(_, let focusedSeconds, _):
            banner = BannerData(
                kind: .explorationComplete(focusedSeconds: focusedSeconds),
                upNextTitle: resolved.title
            )
            pulseNextNodeId = resolved.nodeId
            schedulePulseClear()
        case .bonfireComplete:
            banner = BannerData(kind: .restComplete, upNextTitle: resolved.title)
            pulseNextNodeId = resolved.nodeId
            schedulePulseClear()
        case .bonfireSuggested(let reason, let bonfireId):
            banner = BannerData(kind: .bonfireSuggested(reason: reason), upNextTitle: nil)
            pulseNextNodeId = bonfireId
            schedulePulseClear()
        case .showSettlement:
            // Settlement handled by RootView sheet, no banner needed
            break
        }
    }
    
    func resolveUpNext(after node: TimelineNode?) -> UpNextInfo {
        guard let daySession else { return UpNextInfo(nodeId: nil, title: nil) }
        let nodes = daySession.nodes
        guard !nodes.isEmpty else { return UpNextInfo(nodeId: nil, title: nil) }
        let startIndex: Int
        if let node = node, let idx = nodes.firstIndex(where: { $0.id == node.id }) {
            startIndex = idx + 1
        } else if let current = daySession.currentNode, let idx = nodes.firstIndex(where: { $0.id == current.id }) {
            startIndex = idx + 1
        } else {
            startIndex = 0
        }
        
        for i in startIndex..<nodes.count {
            let n = nodes[i]
            switch n.type {
            case .treasure:
                continue
            case .bonfire(let duration):
                let minutes = max(1, Int(duration / 60))
                return UpNextInfo(nodeId: n.id, title: "Rest (\(minutes)m)")
            case .battle(let boss):
                let minutes = max(1, Int(boss.maxHp / 60))
                return UpNextInfo(nodeId: n.id, title: "\(boss.name) (\(minutes)m)")
            }
        }
        return UpNextInfo(nodeId: nil, title: nil)
    }
    
    func pulseNext(nodeId: UUID?) {
        pulseNextNodeId = nodeId
        schedulePulseClear()
    }
    
    private func schedulePulseClear() {
        guard allowsPulseClear else { return }
        pulseClearTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.pulseNextNodeId = nil
        }
        pulseClearTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }
}

struct UpNextInfo {
    let nodeId: UUID?
    let title: String?
}
