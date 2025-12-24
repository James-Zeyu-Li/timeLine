import Foundation
import Combine
import TimeLineCore

@MainActor
class TimelineViewModel: ObservableObject {
    // Dependencies
    private var engine: BattleEngine?
    private var daySession: DaySession?
    private var stateManager: AppStateManager?
    private var use24HourClock: Bool
    
    // Published State for UI
    @Published var banner: BannerData?
    @Published var pulseNextNodeId: UUID?
    
    private var pulseClearTask: DispatchWorkItem?
    
    init(use24HourClock: Bool = true) {
        self.use24HourClock = use24HourClock
    }
    
    func bind(engine: BattleEngine, daySession: DaySession, stateManager: AppStateManager, use24HourClock: Bool) {
        self.engine = engine
        self.daySession = daySession
        self.stateManager = stateManager
        self.use24HourClock = use24HourClock
    }
    
    // MARK: - Update Preferences
    func updatePreferences(use24HourClock: Bool) {
        self.use24HourClock = use24HourClock
    }
    
    // MARK: - Inbox Management
    func addInboxItem(_ item: TaskTemplate) {
        guard let daySession, let stateManager, let engine else { return }
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.appendTaskTemplate(item, engine: engine)
        removeInboxItem(item)
    }
    
    func removeInboxItem(_ item: TaskTemplate) {
        guard let stateManager else { return }
        stateManager.inbox.removeAll { $0.id == item.id }
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
        let remaining = Int(secondsAhead)
        if remaining <= 0 { return nil }
        let minutes = remaining / 60
        let seconds = remaining % 60
        if minutes > 0 {
            return "in \(minutes)m"
        }
        if seconds > 0 {
            return "in \(seconds)s"
        }
        return nil
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
        case .bonfireComplete:
            banner = BannerData(kind: .restComplete, upNextTitle: resolved.title)
            pulseNextNodeId = resolved.nodeId
            schedulePulseClear()
        case .bonfireSuggested(let reason, let bonfireId):
            banner = BannerData(kind: .bonfireSuggested(reason: reason), upNextTitle: nil)
            pulseNextNodeId = bonfireId
            schedulePulseClear()
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
