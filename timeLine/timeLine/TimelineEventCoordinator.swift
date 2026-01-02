import Foundation
import Combine
import TimeLineCore

/// Central coordinator for timeline events.
/// Unifies event emission and session advancement logic.
/// Direction: Engine.onSessionComplete → Coordinator → (DaySession + UI Events)
final class TimelineEventCoordinator: ObservableObject {
    
    // MARK: - Dependencies
    private let engine: BattleEngine
    private let daySession: DaySession
    private let stateManager: StateSaver
    
    // MARK: - UI Events Publisher
    private let uiEventSubject = PassthroughSubject<TimelineUIEvent, Never>()
    var uiEvents: AnyPublisher<TimelineUIEvent, Never> {
        uiEventSubject.eraseToAnyPublisher()
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var battlesSinceRest = 0
    private var focusedSecondsSinceRest: TimeInterval = 0
    private var hasSuggestedBonfireSinceRest = false
    private let restPromptService = RestPromptService()
    @Published private(set) var lastExplorationReport: FocusGroupFinishedReport?
    @Published private(set) var pendingRestSuggestion: RestSuggestionEvent?
    private var focusGroupSession: FocusGroupSessionCoordinator?
    private var focusGroupNodeId: UUID?
    private var pendingRestAfterSession = false
    
    // MARK: - Init
    init(engine: BattleEngine, daySession: DaySession, stateManager: StateSaver) {
        self.engine = engine
        self.daySession = daySession
        self.stateManager = stateManager
        
        // Subscribe to session complete events (atomic, carries all data)
        engine.onSessionComplete
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handleSessionComplete(result)
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
    }

    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Session Complete Handler
    private var lastProcessedNodeId: UUID?
    
    private func handleSessionComplete(_ result: SessionResult) {
        // Idempotency: prevent duplicate processing for same node
        let completedNode = daySession.currentNode
        let currentNodeId = completedNode?.id
        if let nodeId = currentNodeId, nodeId == lastProcessedNodeId {
            print("[Coordinator] ⚠️ Skipping duplicate event for node: \(nodeId)")
            return
        }
        lastProcessedNodeId = currentNodeId
        
        print("[Coordinator] Received: \(result)")
        
        // Advance to next node
        let advanceSuccess = safeAdvance()
        guard advanceSuccess else { return }
        
        // Emit UI event based on result
        switch result.endReason {
        case .victory:
            battlesSinceRest += 1
            focusedSecondsSinceRest += result.focusedSeconds
            uiEventSubject.send(.victory(
                taskName: result.bossName,
                focusedMinutes: Int(result.focusedSeconds / 60)
            ))
            print("[Coordinator] ✅ Victory: \(result.bossName)")
            
        case .retreat:
            battlesSinceRest += 1
            focusedSecondsSinceRest += result.focusedSeconds
            // Only emit retreat banner if significant wasted time (>= 3 min)
            if result.wastedSeconds >= 180 {
                uiEventSubject.send(.retreat(
                    taskName: result.bossName,
                    wastedMinutes: Int(result.wastedSeconds / 60)
                ))
            }
            print("[Coordinator] 🏳️ Retreat: \(result.bossName), wasted \(Int(result.wastedSeconds))s")
            
        case .incompleteExit:
            battlesSinceRest += 1
            focusedSecondsSinceRest += result.focusedSeconds
            uiEventSubject.send(.incompleteExit(
                taskName: result.bossName,
                focusedSeconds: result.focusedSeconds,
                remainingSeconds: result.remainingSecondsAtExit
            ))
            print("[Coordinator] ⏹️ Incomplete Exit: \(result.bossName)")

        case .completedExploration:
            battlesSinceRest += 1
            focusedSecondsSinceRest += result.focusedSeconds
            recordExplorationReport(result: result, completedNode: completedNode)
            uiEventSubject.send(.completedExploration(
                taskName: result.bossName,
                focusedSeconds: result.focusedSeconds,
                summary: result.focusGroupSummary
            ))
            print("[Coordinator] 🧭 Exploration Complete: \(result.bossName)")
            clearFocusGroupSession()
        }
        
        maybeSuggestBonfire()

        if let nodeId = currentNodeId, nodeId == focusGroupNodeId {
            clearFocusGroupSession()
        }

        if pendingRestAfterSession {
            pendingRestAfterSession = false
            startSuggestedRest(duration: 600)
        }
        
        stateManager.requestSave()
    }

    func recordFocusProgress(seconds: TimeInterval) {
        guard pendingRestSuggestion == nil else { return }
        if let event = restPromptService.recordFocus(seconds: seconds) {
            pendingRestSuggestion = event
        }
    }

    private func recordExplorationReport(
        result: SessionResult,
        completedNode: TimelineNode?
    ) {
        guard let summary = result.focusGroupSummary else { return }
        let memberIds = resolveMemberIds(from: completedNode, fallback: summary.allocations)
        let entries = memberIds.map { id in
            FocusGroupReportEntry(
                templateId: id,
                focusedSeconds: summary.allocations[id, default: 0]
            )
        }
        lastExplorationReport = FocusGroupFinishedReport(
            taskName: result.bossName,
            totalFocusedSeconds: summary.totalFocusedSeconds,
            entries: entries
        )
    }

    private func resolveMemberIds(
        from node: TimelineNode?,
        fallback allocations: [UUID: TimeInterval]
    ) -> [UUID] {
        if case .battle(let boss) = node?.type,
           let payload = boss.focusGroupPayload,
           !payload.memberTemplateIds.isEmpty {
            return payload.memberTemplateIds
        }
        return allocations.keys.sorted { $0.uuidString < $1.uuidString }
    }

    func clearExplorationReport() {
        lastExplorationReport = nil
    }

    func ensureFocusGroupSession(for node: TimelineNode) -> FocusGroupSessionCoordinator? {
        guard case .battle(let boss) = node.type,
              let payload = boss.focusGroupPayload else { return nil }
        if focusGroupNodeId != node.id {
            let elapsed = engine.currentSessionElapsed() ?? 0
            let startTime = Date().addingTimeInterval(-elapsed)
            let session = FocusGroupSessionCoordinator(
                memberTemplateIds: payload.memberTemplateIds,
                startTime: startTime,
                activeIndex: payload.activeIndex
            )
            focusGroupSession = session
            focusGroupNodeId = node.id
        }
        return focusGroupSession
    }

    @discardableResult
    func switchFocusGroup(to index: Int, nodeId: UUID, at time: Date = Date()) -> Bool {
        guard let session = focusGroupSession else { return false }
        let didSwitch = session.switchTo(index: index, at: time)
        guard didSwitch else { return false }
        updateFocusGroupActiveIndex(nodeId: nodeId, activeIndex: index)
        return true
    }

    func endFocusGroupSession(at time: Date = Date()) -> FocusGroupSessionSummary? {
        guard let session = focusGroupSession else { return nil }
        return session.endExploration(at: time)
    }

    private func updateFocusGroupActiveIndex(nodeId: UUID, activeIndex: Int) {
        guard let index = daySession.nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        guard case .battle(var boss) = daySession.nodes[index].type,
              var payload = boss.focusGroupPayload else { return }
        payload.activeIndex = activeIndex
        boss.focusGroupPayload = payload
        daySession.nodes[index].type = .battle(boss)
        stateManager.requestSave()
    }

    private func clearFocusGroupSession() {
        focusGroupSession = nil
        focusGroupNodeId = nil
    }
    
    // MARK: - Bonfire Completion
    /// Called by BonfireView when user taps "Resume Journey"
    func completeBonfire() {
        let advanceSuccess = safeAdvance()
        guard advanceSuccess else { return }
        
        engine.endRest()
        stateManager.requestSave()
        resetBonfireSuggestionCounters()
        restPromptService.resetAfterRest()
        
        uiEventSubject.send(.bonfireComplete)
        print("[Coordinator] 🔥 Bonfire complete, advancing to next node")
    }

    func acceptRestSuggestion(duration: TimeInterval = 600) {
        guard pendingRestSuggestion != nil else { return }
        pendingRestSuggestion = nil
        restPromptService.resetAfterRest()
        pendingRestAfterSession = true
        if let node = daySession.currentNode,
           case .battle(let boss) = node.type,
           boss.focusGroupPayload != nil {
            let summary = endFocusGroupSession(at: Date())
            engine.endExploration(summary: summary, at: Date())
        } else {
            engine.retreat()
        }
    }

    func declineRestSuggestion() {
        guard pendingRestSuggestion != nil else { return }
        pendingRestSuggestion = nil
        restPromptService.resetAfterContinue()
    }

    private func startSuggestedRest(duration: TimeInterval) {
        let insertIndex = min(max(0, daySession.currentIndex), daySession.nodes.count)
        if insertIndex < daySession.nodes.count,
           case .bonfire = daySession.nodes[insertIndex].type {
            daySession.currentIndex = insertIndex
            engine.startRest(duration: duration)
            stateManager.requestSave()
            return
        }
        let node = TimelineNode(type: .bonfire(duration), isLocked: false)
        daySession.nodes.insert(node, at: insertIndex)
        daySession.resetCurrentToFirstUpcoming()
        engine.startRest(duration: duration)
        stateManager.requestSave()
    }
    
    // MARK: - Safe Advance
    /// Advances daySession with bounds checking.
    /// Returns true if advance was successful.
    private func safeAdvance() -> Bool {
        let currentIndex = daySession.currentIndex
        let nodeCount = daySession.nodes.count
        
        // Check if we can advance
        if nodeCount == 0 {
            print("[Coordinator] ⚠️ Cannot advance: nodes array is empty")
            return false
        }
        
        if currentIndex >= nodeCount - 1 {
            print("[Coordinator] ℹ️ Already at last node (index \(currentIndex) of \(nodeCount))")
            // Still call advance to mark current as complete, but no next node
        }
        
        daySession.advance()
        print("[Coordinator] Advanced from index \(currentIndex) to \(daySession.currentIndex)")
        return true
    }
    
    private func resetBonfireSuggestionCounters() {
        battlesSinceRest = 0
        focusedSecondsSinceRest = 0
        hasSuggestedBonfireSinceRest = false
    }
    
    private func maybeSuggestBonfire() {
        guard !hasSuggestedBonfireSinceRest else { return }
        
        let battleThreshold = 2
        let focusThreshold: TimeInterval = 45 * 60
        
        let shouldSuggest = battlesSinceRest >= battleThreshold || focusedSecondsSinceRest >= focusThreshold
        guard shouldSuggest else { return }
        guard let nextBonfire = resolveNextBonfire() else { return }
        
        let reason: String
        if battlesSinceRest >= battleThreshold {
            reason = "连续战斗较多，建议休息"
        } else {
            reason = "专注时间过久，建议放松"
        }
        
        hasSuggestedBonfireSinceRest = true
        uiEventSubject.send(.bonfireSuggested(reason: reason, bonfireId: nextBonfire.id))
    }
    
    private func resolveNextBonfire() -> TimelineNode? {
        let nodes = daySession.nodes
        guard !nodes.isEmpty else { return nil }
        let startIndex = min(daySession.currentIndex, nodes.count - 1)
        for i in startIndex..<nodes.count {
            if case .bonfire = nodes[i].type {
                return nodes[i]
            }
        }
        return nil
    }
}

// MARK: - Preview/Test Support
extension TimelineEventCoordinator {
    /// Creates a coordinator with empty/mock dependencies for previews
    static var preview: TimelineEventCoordinator {
        TimelineEventCoordinator(
            engine: BattleEngine(),
            daySession: DaySession(nodes: []),
            stateManager: AppStateManager(
                engine: BattleEngine(),
                daySession: DaySession(nodes: []),
                cardStore: CardTemplateStore(),
                libraryStore: LibraryStore()
            )
        )
    }
}

struct FocusGroupFinishedReport: Identifiable, Equatable {
    let id = UUID()
    let taskName: String
    let totalFocusedSeconds: TimeInterval
    let entries: [FocusGroupReportEntry]
}

struct FocusGroupReportEntry: Equatable {
    let templateId: UUID
    let focusedSeconds: TimeInterval
}
