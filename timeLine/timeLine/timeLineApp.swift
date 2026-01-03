import SwiftUI
import TimeLineCore

@main
struct AppEntryPoint {
    static func main() {
        if isRunningTests {
            if isRunningUITests {
                TimeLineApp.main()
            } else {
                TestApp.main()
            }
        } else {
            TimeLineApp.main()
        }
    }
    
    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }
    
    private static var isRunningUITests: Bool {
        let env = ProcessInfo.processInfo.environment
        let args = ProcessInfo.processInfo.arguments
        return env["UITESTS"] == "1" || env["XCUI_TESTS"] == "1" || args.contains("-ui-testing")
    }
}

struct TimeLineApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    // Core State Objects
    @StateObject private var engine = BattleEngine()
    @StateObject private var daySession: DaySession
    @StateObject private var cardStore: CardTemplateStore
    @StateObject private var libraryStore: LibraryStore
    @StateObject private var focusListStore = FocusListStore()
    @StateObject private var deckStore = DeckStore()
    @StateObject private var appMode = AppModeManager()
    @StateObject private var stateManager: AppStateManager
    @StateObject private var coordinator: TimelineEventCoordinator
    
    @State private var showNewDayAlert = false
    @State private var yesterdayFocusTime: TimeInterval = 0
    
    // First-launch detection
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    init() {
        let env = ProcessInfo.processInfo.environment
        let args = ProcessInfo.processInfo.arguments
        let isUITesting = env["UITESTS"] == "1" || env["XCUI_TESTS"] == "1" || args.contains("-ui-testing")
        let wantsEmptyTimeline = args.contains("-empty-timeline") || env["EMPTY_TIMELINE"] == "1"
        if isUITesting {
            // Ensure UI tests start from a consistent state.
            PersistenceManager.shared.resetData()
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        }
        
        // Try to load persistence (unless UI tests force an empty timeline)
        let initialDaySession: DaySession
        if wantsEmptyTimeline {
            initialDaySession = DaySession(nodes: [])
        } else if let state = PersistenceManager.shared.load() {
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
        let cardStore = CardTemplateStore()
        let libraryStore = LibraryStore()
        
        _engine = StateObject(wrappedValue: engine)
        _cardStore = StateObject(wrappedValue: cardStore)
        _libraryStore = StateObject(wrappedValue: libraryStore)
        
        // Create state manager
        let manager = AppStateManager(
            engine: engine,
            daySession: initialDaySession,
            cardStore: cardStore,
            libraryStore: libraryStore
        )
        _stateManager = StateObject(wrappedValue: manager)
        
        // Create event coordinator (unifies event emission)
        let coord = TimelineEventCoordinator(
            engine: engine,
            daySession: initialDaySession,
            stateManager: manager
        )
        _coordinator = StateObject(wrappedValue: coord)
    }
    
    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                RootView()
                    .environmentObject(engine)
                    .environmentObject(daySession)
                    .environmentObject(cardStore)
                    .environmentObject(libraryStore)
                    .environmentObject(focusListStore)
                    .environmentObject(deckStore)
                    .environmentObject(appMode)
                    .environmentObject(stateManager)
                    .environmentObject(coordinator)
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
            } else {
                OnboardingView(onComplete: {
                    print("Debug: Onboarding Completed")
                    hasSeenOnboarding = true
                })
                .onAppear { print("Debug: Showing Onboarding View. hasSeen=\(hasSeenOnboarding)") }
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
        let env = ProcessInfo.processInfo.environment
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-empty-timeline") || env["EMPTY_TIMELINE"] == "1" {
            daySession.nodes = []
            daySession.currentIndex = 0
            return
        }
        if let state = PersistenceManager.shared.load() {
            // Restore Engine State
            if let engineState = state.engineState {
                engine.restore(from: engineState)
            }
            
            cardStore.load(from: state.cardTemplates)
            cardStore.seedDefaultsIfNeeded()
            libraryStore.load(from: state.libraryEntries)
            stateManager.spawnedKeys = state.spawnedKeys
            stateManager.inbox = state.inbox
            
            // Reconcile or Reset Day
            if !Calendar.current.isDateInToday(state.lastSeenAt) {
                // IT'S A NEW DAY
                print("[TimeLineApp] New Day Detected! Resetting session.")

                // Ephemeral Cleanup: remove unsaved ad-hoc templates from last day
                cleanupEphemeralTemplates()

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
                    templates: cardStore.orderedTemplates(),
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
                engine.freezeTokensUsed = 0
                engine.freezeHistory.removeAll()
                
                // 3. Trigger Alert
                showNewDayAlert = true
                
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

    private func cleanupEphemeralTemplates() {
        let toRemove = cardStore.orderedTemplates().filter { $0.isEphemeral }
        guard !toRemove.isEmpty else { return }
        for template in toRemove {
            cardStore.remove(id: template.id)
            libraryStore.remove(templateId: template.id)
        }
        print("[TimeLineApp] Ephemeral cleanup removed \(toRemove.count) templates.")
    }
    
    func checkForNewDay() {
        // For V0, restoreState covers 99% of use cases (user sleeps).
        // Live midnight crossover is rare.
    }
}
