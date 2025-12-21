import SwiftUI
import TimeLineCore

@main
struct TimeLineApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    // Shared State
    @StateObject private var engine = BattleEngine()
    @StateObject private var daySession: DaySession
    @StateObject private var templateStore = TemplateStore() // NEW: Template Store
    
    init() {
        // Try to load persistence
        if let state = PersistenceManager.shared.load() {
            // Restore DaySession
            _daySession = StateObject(wrappedValue: state.daySession)
            // Template Store initialization is deferred to onAppear/restore
        } else {
            // Default Init
            let demoTasks = [
                Boss(name: "Morning Email", maxHp: 900), // 15m
                Boss(name: "Code Review", maxHp: 1800),  // 30m
                Boss(name: "Write Report", maxHp: 2700)  // 45m
            ]
            let route = RouteGenerator.generateRoute(from: demoTasks)
            _daySession = StateObject(wrappedValue: DaySession(nodes: route))
        }
    }
    
    @State private var showNewDayAlert = false
    @State private var yesterdayFocusTime: TimeInterval = 0
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(engine)
                .environmentObject(daySession)
                .environmentObject(templateStore) // NEW
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
                saveState()
            case .active:
                // Check if we crossed midnight while backgrounded
                checkForNewDay()
                engine.handleForegrounding()
            case .inactive:
                saveState()
            default:
                break
            }
        }
    }
    
    func saveState() {
        let snapshot = engine.snapshot()
        
        let state = AppState(
            lastSeenAt: Date(),
            daySession: daySession,
            engineState: snapshot,
            history: engine.history, // Use engine's history directly
            templates: templateStore.templates // NEW: Save templates
        )
        PersistenceManager.shared.save(state: state)
    }
    
    func restoreState() {
        if let state = PersistenceManager.shared.load() {
            // Restore Engine State
            if let engineState = state.engineState {
                engine.restore(from: engineState)
            }
            
            // Restore Templates (NEW)
            templateStore.load(from: state.templates)
            
            // Reconcile or Reset Day
            if !Calendar.current.isDateInToday(state.lastSeenAt) {
                // IT'S A NEW DAY
                print("[TimeLineApp] New Day Detected! Resetting session.")
                
                // 1. Capture yesterday's stats (already saved in history, but good for display)
                if let history = state.history.last, Calendar.current.isDate(history.date, inSameDayAs: state.lastSeenAt) {
                     yesterdayFocusTime = history.totalFocusedTime
                } else {
                     yesterdayFocusTime = engine.totalFocusedHistoryToday // fallback
                }
                
                // 2. Reset Data
                
                // NEW: Auto-Spawn Repeating Tasks
                let repeatingTasks = TemplateManager.processRepeats(templates: state.templates, for: Date())
                if !repeatingTasks.isEmpty {
                    // Generate route from repeating tasks
                    let route = RouteGenerator.generateRoute(from: repeatingTasks)
                    daySession.nodes = route
                } else {
                    daySession.nodes = [] // Clear all nodes if no repeats
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
        // Simple check: existing history vs today
        // If engine says we have focus time today, but we just realized it's actually "Tomorrow" relative to last check?
        // Actually, restoreState handles the Launch case. 
        // This function handles the "App stayed open across midnight" case.
        
        // TODO: For strict correctness, we should store `currentDay` in state or use `lastSeenAt`.
        // Since we update `lastSeenAt` on save (background), checking here is mostly for live transitions.
        // For V0, `restoreState` covers 99% of use cases (user sleeps). 
        // Live midnight crossover is rare. Let's rely on standard restore for now.
    }
}
