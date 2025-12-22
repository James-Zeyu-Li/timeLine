import SwiftUI
import TimeLineCore

@main
struct TimeLineApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    // Core State Objects
    @StateObject private var engine = BattleEngine()
    @StateObject private var daySession: DaySession
    @StateObject private var templateStore = TemplateStore()
    @StateObject private var stateManager: AppStateManager
    
    @State private var showNewDayAlert = false
    @State private var yesterdayFocusTime: TimeInterval = 0
    
    init() {
        // Try to load persistence
        let initialDaySession: DaySession
        if let state = PersistenceManager.shared.load() {
            initialDaySession = state.daySession
        } else {
            // Default Init
            let demoTasks = [
                Boss(name: "Morning Email", maxHp: 900),
                Boss(name: "Code Review", maxHp: 1800),
                Boss(name: "Write Report", maxHp: 2700)
            ]
            let route = RouteGenerator.generateRoute(from: demoTasks)
            initialDaySession = DaySession(nodes: route)
        }
        
        _daySession = StateObject(wrappedValue: initialDaySession)
        
        // Create shared objects first
        let engine = BattleEngine()
        let templateStore = TemplateStore()
        
        _engine = StateObject(wrappedValue: engine)
        _templateStore = StateObject(wrappedValue: templateStore)
        
        // Create state manager
        let manager = AppStateManager(
            engine: engine,
            daySession: initialDaySession,
            templateStore: templateStore
        )
        _stateManager = StateObject(wrappedValue: manager)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(engine)
                .environmentObject(daySession)
                .environmentObject(templateStore)
                .environmentObject(stateManager)
                .onAppear {
                    restoreState()
                }
                .alert(isPresented: $showNewDayAlert) {
                    Alert(
                        title: Text("Glorious New Day!"),
                        message: Text("Yesterday you focused for \(Int(yesterdayFocusTime / 60)) minutes.\nThe timeline has been reset."),
                        dismissButton: .default(Text("Let's Go"))
                    )
                }
        }
        .onChange(of: scenePhase) { oldValue, newPhase in
            switch newPhase {
            case .background:
                engine.handleBackgrounding()
                stateManager.saveNow()
            case .active:
                checkForNewDay()
                engine.handleForegrounding()
            case .inactive:
                stateManager.saveNow()
            default:
                break
            }
        }
    }
    
    func restoreState() {
        if let state = PersistenceManager.shared.load() {
            // Restore Engine State
            if let engineState = state.engineState {
                engine.restore(from: engineState)
            }
            
            // Restore Templates
            templateStore.load(from: state.templates)
            stateManager.spawnedKeys = state.spawnedKeys
            
            // Reconcile or Reset Day
            if !Calendar.current.isDateInToday(state.lastSeenAt) {
                // IT'S A NEW DAY
                print("[TimeLineApp] New Day Detected! Resetting session.")
                
                // 1. Capture yesterday's stats
                if let history = state.history.last, Calendar.current.isDate(history.date, inSameDayAs: state.lastSeenAt) {
                    yesterdayFocusTime = history.totalFocusedTime
                } else {
                    yesterdayFocusTime = engine.totalFocusedHistoryToday
                }
                
                // 2. Reset Data for New Day
                stateManager.spawnedKeys.removeAll()
                
                // Auto-Spawn Repeating Tasks
                let (tasks, newKeys) = SpawnManager.processRepeats(
                    templates: state.templates,
                    for: Date(),
                    ledger: stateManager.spawnedKeys
                )
                
                // Update Ledger
                for key in newKeys {
                    stateManager.spawnedKeys.insert(key)
                }
                
                if !tasks.isEmpty {
                    let route = RouteGenerator.generateRoute(from: tasks)
                    daySession.nodes = route
                } else {
                    daySession.nodes = []
                }
                
                daySession.currentIndex = 0
                engine.totalFocusedHistoryToday = 0
                engine.currentBoss = nil
                engine.state = .idle
                engine.wastedTime = 0
                
                // 3. Trigger Alert
                showNewDayAlert = true
                
            } else {
                // SAME DAY: Continue as normal
                engine.reconcile(lastSeenAt: state.lastSeenAt)
                
                // Restore DaySession
                daySession.nodes = state.daySession.nodes
                daySession.currentIndex = state.daySession.currentIndex
            }
        }
    }
    
    func checkForNewDay() {
        // For V0, restoreState covers 99% of use cases (user sleeps).
        // Live midnight crossover is rare.
    }
}
