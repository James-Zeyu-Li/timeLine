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
            uiEventSubject.send(.victory(
                taskName: bossName,
                focusedMinutes: Int(focusedSeconds / 60)
            ))
            print("[Coordinator] ✅ Victory: \(bossName)")
            
        case .retreat(let bossName, _, let wastedSeconds):
            // Only emit retreat banner if significant wasted time (>= 3 min)
            if wastedSeconds >= 180 {
                uiEventSubject.send(.retreat(
                    taskName: bossName,
                    wastedMinutes: Int(wastedSeconds / 60)
                ))
            }
            print("[Coordinator] 🏳️ Retreat: \(bossName), wasted \(Int(wastedSeconds))s")
        }
        
        stateManager.requestSave()
    }
    
    // MARK: - Bonfire Completion
    /// Called by BonfireView when user taps "Resume Journey"
    func completeBonfire() {
        let advanceSuccess = safeAdvance()
        guard advanceSuccess else { return }
        
        engine.endRest()
        stateManager.requestSave()
        
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
                templateStore: TemplateStore()
            )
        )
    }
}
