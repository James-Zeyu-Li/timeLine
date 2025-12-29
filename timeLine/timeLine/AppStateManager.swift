import SwiftUI
import Combine
import TimeLineCore

/// Centralized manager for app-level state and persistence.
/// Save is debounced to avoid excessive writes.
final class AppStateManager: ObservableObject, StateSaver {
    
    // MARK: - Dependencies
    let engine: BattleEngine
    let daySession: DaySession
    let cardStore: CardTemplateStore
    
    // MARK: - Ledger
    @Published var spawnedKeys: Set<String> = []
    @Published var inbox: [UUID] = []
    
    // MARK: - Debounced Save
    private let saveSubject = PassthroughSubject<Void, Never>()
    private var saveCancellable: AnyCancellable?
    
    init(
        engine: BattleEngine,
        daySession: DaySession,
        cardStore: CardTemplateStore,
        enablePersistence: Bool = true
    ) {
        self.engine = engine
        self.daySession = daySession
        self.cardStore = cardStore
        
        // Debounce saves by 500ms
        if enablePersistence {
            saveCancellable = saveSubject
                .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
                .sink { [weak self] in
                    self?.performSave()
                }
            print("[AppStateManager] Initialized. Debounce: 500ms")
        } else {
            print("[AppStateManager] Initialized (Persistence Disabled)")
        }
    }
    
    /// Request a save. Will be debounced.
    func requestSave() {
        saveSubject.send()
    }
    
    /// Immediate save (for scenePhase changes)
    func saveNow() {
        performSave()
    }
    
    private func performSave() {
        // Validation: ensure currentIndex is valid
        if !daySession.nodes.isEmpty {
            let maxValidIndex = daySession.nodes.count - 1
            if daySession.currentIndex < 0 || daySession.currentIndex > maxValidIndex {
                print("[AppStateManager] ⚠️ Warning: currentIndex (\(daySession.currentIndex)) out of bounds [0..\(maxValidIndex)]. Clamping.")
                daySession.currentIndex = min(max(0, daySession.currentIndex), maxValidIndex)
            }
        } else if daySession.currentIndex != 0 {
            // Empty nodes but non-zero index
            print("[AppStateManager] ⚠️ Warning: nodes empty but currentIndex=\(daySession.currentIndex). Resetting to 0.")
            daySession.currentIndex = 0
        }
        
        let snapshot = engine.snapshot()
        
        let state = AppState(
            lastSeenAt: Date(),
            daySession: daySession,
            engineState: snapshot,
            history: engine.history,
            cardTemplates: cardStore.orderedTemplates(),
            inbox: inbox,
            spawnedKeys: spawnedKeys
        )
        PersistenceManager.shared.save(state: state)
        print("[AppStateManager] State saved.")
    }
    
    // MARK: - Restore
    
    func restore() -> Bool {
        guard let state = PersistenceManager.shared.load() else {
            return false
        }
        
        // Restore engine state
        if let engineState = state.engineState {
            engine.restore(from: engineState)
        }
        
        cardStore.load(from: state.cardTemplates)
        cardStore.seedDefaultsIfNeeded()
        inbox = state.inbox
        self.spawnedKeys = state.spawnedKeys
        
        return true
    }
    
    // MARK: - Reset
    
    /// Reset all app data to first-install state
    /// - Clears all persisted data
    /// - Resets onboarding flag (will show onboarding again)
    /// - Loads default templates
    /// - Creates demo tasks for timeline
    func resetAllData() {
        // Clear persisted file
        PersistenceManager.shared.resetData()
        
        // Reset onboarding flag to show welcome screen
        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
        UserDefaults.standard.synchronize()
        
        // Clear in-memory state
        daySession.nodes.removeAll()
        daySession.currentIndex = 0
        spawnedKeys.removeAll()
        inbox.removeAll()
        
        // Reset engine
        engine.state = .idle
        engine.currentBoss = nil
        engine.wastedTime = 0
        engine.totalFocusedHistoryToday = 0
        engine.history.removeAll()
        engine.freezeTokensUsed = 0
        engine.freezeHistory.removeAll()
        
        cardStore.reset()
        cardStore.seedDefaultsIfNeeded()
        
        // Create demo journey for first-time experience
        let demoTasks = [
            Boss(name: "Morning Planning", maxHp: 900, category: .work),
            Boss(name: "Focus Session", maxHp: 2700, category: .work),
            Boss(name: "Review & Reflect", maxHp: 1200, category: .work)
        ]
        let route = RouteGenerator.generateRoute(from: demoTasks)
        daySession.nodes = route
        daySession.currentIndex = 0
        if !route.isEmpty {
            daySession.nodes[0].isLocked = false
        }
        
        print("[AppStateManager] ✅ All data reset complete. App restored to first-install state.")
        print("[AppStateManager] 👋 Onboarding will show on next launch.")
    }
}
