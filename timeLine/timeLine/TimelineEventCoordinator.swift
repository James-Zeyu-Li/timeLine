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
    private let stateManager: AppStateManager
    
    // MARK: - UI Events Publisher
    private let uiEventSubject = PassthroughSubject<TimelineUIEvent, Never>()
    var uiEvents: AnyPublisher<TimelineUIEvent, Never> {
        uiEventSubject.eraseToAnyPublisher()
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var battlesSinceRest = 0
    private var focusedSecondsSinceRest: TimeInterval = 0
    private var hasSuggestedBonfireSinceRest = false
    
    // MARK: - Init
    init(engine: BattleEngine, daySession: DaySession, stateManager: AppStateManager) {
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
    
    // MARK: - Session Complete Handler
    private var lastProcessedNodeId: UUID?
    
    private func handleSessionComplete(_ result: SessionResult) {
        // Idempotency: prevent duplicate processing for same node
        let currentNodeId = daySession.currentNode?.id
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
        switch result {
        case .victory(let bossName, let focusedSeconds, _):
            battlesSinceRest += 1
            focusedSecondsSinceRest += focusedSeconds
            uiEventSubject.send(.victory(
                taskName: bossName,
                focusedMinutes: Int(focusedSeconds / 60)
            ))
            print("[Coordinator] ✅ Victory: \(bossName)")
            
        case .retreat(let bossName, let focusedSeconds, let wastedSeconds):
            battlesSinceRest += 1
            focusedSecondsSinceRest += focusedSeconds
            // Only emit retreat banner if significant wasted time (>= 3 min)
            if wastedSeconds >= 180 {
                uiEventSubject.send(.retreat(
                    taskName: bossName,
                    wastedMinutes: Int(wastedSeconds / 60)
                ))
            }
            print("[Coordinator] 🏳️ Retreat: \(bossName), wasted \(Int(wastedSeconds))s")
        }
        
        maybeSuggestBonfire()
        
        stateManager.requestSave()
    }
    
    // MARK: - Bonfire Completion
    /// Called by BonfireView when user taps "Resume Journey"
    func completeBonfire() {
        let advanceSuccess = safeAdvance()
        guard advanceSuccess else { return }
        
        engine.endRest()
        stateManager.requestSave()
        resetBonfireSuggestionCounters()
        
        uiEventSubject.send(.bonfireComplete)
        print("[Coordinator] 🔥 Bonfire complete, advancing to next node")
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
                cardStore: CardTemplateStore()
            )
        )
    }
}
