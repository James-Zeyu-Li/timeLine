import SwiftUI
import Combine
import TimeLineCore

/// Centralized manager for app-level state and persistence.
/// Save is debounced to avoid excessive writes.
final class AppStateManager: ObservableObject {
    
    // MARK: - Dependencies
    let engine: BattleEngine
    let daySession: DaySession
    let templateStore: TemplateStore
    
    // MARK: - Ledger
    @Published var spawnedKeys: Set<String> = []
    
    // MARK: - Debounced Save
    private let saveSubject = PassthroughSubject<Void, Never>()
    private var saveCancellable: AnyCancellable?
    
    init(engine: BattleEngine, daySession: DaySession, templateStore: TemplateStore) {
        self.engine = engine
        self.daySession = daySession
        self.templateStore = templateStore
        
        // Debounce saves by 500ms
        saveCancellable = saveSubject
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.performSave()
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
        let snapshot = engine.snapshot()
        
        let state = AppState(
            lastSeenAt: Date(),
            daySession: daySession,
            engineState: snapshot,
            history: engine.history,
            templates: templateStore.templates,
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
        
        // Restore templates
        templateStore.load(from: state.templates)
        self.spawnedKeys = state.spawnedKeys
        
        return true
    }
}
