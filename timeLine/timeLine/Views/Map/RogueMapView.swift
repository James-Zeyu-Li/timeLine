import SwiftUI
import TimeLineCore

struct RogueMapView: View {
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var coordinator: TimelineEventCoordinator
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    @EnvironmentObject var masterClock: MasterClockService
    
    // View Model
    @StateObject private var viewModel = MapViewModel()
    
    @AppStorage("use24HourClock") private var use24HourClock = true
    
    @State private var showStats = false
    @State private var statsInitialRange: StatsTimeRange?
    @State private var nodeAnchors: [UUID: CGFloat] = [:]
    @State private var nodeFrames: [UUID: CGRect] = [:]
    @State private var viewportHeight: CGFloat = 0

    @State private var showNodeActionMenu = false
    @State private var selectedNodeId: UUID?
    @State private var actionMenuNode: TimelineNode?
    @State private var isEditMode = false
    
    @Binding var showJumpButton: Bool
    @Binding var scrollToNowTrigger: Int
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background
                PixelTheme.background
                    .ignoresSafeArea()
                    .overlay(
                         Color(hex: masterClock.timeOfDay.colorHex)
                            .opacity(0.15)
                            .ignoresSafeArea()
                            .animation(.linear(duration: 1.0), value: masterClock.timeOfDay)
                    )
                
                // Main timeline view
                VStack(spacing: 0) {
                    // Header
                    TimelineHeaderView(
                        currentChapter: viewModel.currentChapter,
                        journeyTitle: viewModel.journeyTitle,
                        currentLevel: viewModel.currentLevel,
                        totalFocusedTime: engine.totalFocusedToday,
                        completionProgress: daySession.completionProgress,
                        isEditMode: $isEditMode,
                        showStats: $showStats,
                        statsInitialRange: $statsInitialRange
                    )
                    
                    // Timeline scroll view
                    TimelineListView(
                        viewModel: viewModel,
                        onAction: handleAction,
                        nodeFrames: $nodeFrames,
                        viewportHeight: $viewportHeight,
                        isEditMode: $isEditMode,
                        showJumpButton: $showJumpButton,
                        scrollToNowTrigger: $scrollToNowTrigger
                    )
                }
            }
            .onAppear {
                viewportHeight = proxy.size.height
                print("📱 [Viewport] Height: \(proxy.size.height)")
                
                // Bind viewModel to dependencies for time calculations
                viewModel.bind(
                    engine: engine,
                    daySession: daySession,
                    stateManager: stateManager,
                    cardStore: cardStore,
                    use24HourClock: use24HourClock
                )
            }
            .onChange(of: proxy.size) { _, newSize in
                viewportHeight = newSize.height
            }
            .onChange(of: use24HourClock) { _, newValue in
                // Update viewModel preferences when clock format changes
                viewModel.updatePreferences(use24HourClock: newValue)
            }
            .sheet(isPresented: $showStats, onDismiss: { statsInitialRange = nil }) {
                AdventurerLogView(initialRange: statsInitialRange)
            }
            .confirmationDialog(
                actionMenuNode.map { nodeTitle(for: $0) } ?? "Task",
                isPresented: $showNodeActionMenu,
                titleVisibility: .visible
            ) {
                if let node = actionMenuNode {
                    Button("Edit") {
                        handleEdit(on: node)
                    }
                    Button("Duplicate") {
                        handleDuplicate(on: node)
                    }
                    Button("Delete", role: .destructive) {
                        handleDelete(on: node)
                    }
                    Button("Cancel", role: .cancel) { }
                }
            }
        }
    }
    
    private func nodeTitle(for node: TimelineNode) -> String {
        switch node.type {
        case .battle(let boss):
            return boss.name
        case .bonfire:
            return "Break"
        case .treasure:
            return "Field Note"
        }
    }
    
    // MARK: - Action Handling
    
    private func handleAction(_ action: TimelineNodeAction) {
        switch action {
        case .tap(let node):
            handleTap(on: node)
        case .edit(let node):
            handleEdit(on: node)
        case .duplicate(let node):
            handleDuplicate(on: node)
        case .delete(let node):
            handleDelete(on: node)
        case .moveUp(let node):
            handleMove(node: node, direction: -1)
        case .moveDown(let node):
            handleMove(node: node, direction: 1)
        }
    }
    
    private func handleTap(on node: TimelineNode) -> Void {
        print("👆 [Tap] handleTap triggered on node: \(node.id)")
        guard !node.isCompleted else {
            Haptics.impact(.light)
            return
        }

        if case .battle(let boss) = node.type {
            let behavior = node.effectiveTaskBehavior { id in
                cardStore.get(id: id)
            }
            if behavior == .reminder {
                coordinator.completeReminder(nodeId: node.id)
                Haptics.impact(.medium)
                return
            }
            // Use boss to fix unused variable warning
             _ = boss 
        }

        let isFirstUpcoming = viewModel.upcomingNodes.first?.id == node.id
        if !viewModel.isSessionActive && isFirstUpcoming {
            // Allow start even if lock state is stale.
        } else {
            guard !node.isLocked, !node.isCompleted else {
                Haptics.impact(.light)
                return
            }
        }
        
        switch node.type {
        case .battle(let boss):
            let taskMode = node.effectiveTaskMode { id in
                cardStore.get(id: id)
            }
            if node.id != daySession.currentNode?.id {
                Haptics.impact(.medium)
                daySession.setCurrentNode(id: node.id)
                engine.startBattle(boss: boss, taskMode: taskMode)
                if let tid = boss.templateId {
                    cardStore.markUsed(id: tid)
                }
                stateManager.requestSave()
            } else {
                if engine.state == .frozen {
                    engine.resumeFromFreeze()
                    stateManager.requestSave()
                } else if engine.state != .fighting {
                    engine.startBattle(boss: boss, taskMode: taskMode)
                } else {
                    Haptics.impact(.light)
                }
            }
        case .bonfire(let duration):
            if node.id != daySession.currentNode?.id {
                Haptics.impact(.medium)
                daySession.setCurrentNode(id: node.id)
                engine.startRest(duration: duration)
                stateManager.requestSave()
            } else {
                engine.startRest(duration: duration)
            }
        case .treasure:
            break
        }
    }
    
    private func handleLongPress(on node: TimelineNode) {
        actionMenuNode = node
        showNodeActionMenu = true
    }
    
    private func handleEdit(on node: TimelineNode) {
        guard case .battle(let boss) = node.type else { return }
        
        let templateToEdit: CardTemplate
        
        if let templateId = boss.templateId, let template = cardStore.get(id: templateId) {
            templateToEdit = template
        } else {
            // Transient or missing template: create one and add to store
            let newTemplate = CardTemplate(
                id: boss.templateId ?? UUID(),
                title: boss.name,
                icon: "bolt.fill",
                defaultDuration: boss.maxHp,
                tags: [],
                energyColor: .focus,
                category: boss.category,
                style: boss.style,
                taskMode: node.effectiveTaskMode { id in
                    cardStore.get(id: id)
                },
                remindAt: boss.remindAt,
                leadTimeMinutes: boss.leadTimeMinutes
            )
            cardStore.add(newTemplate)
            templateToEdit = newTemplate
        }
        
        // Enter global edit mode
        appMode.enterCardEdit(cardTemplateId: templateToEdit.id)
    }
    
    private func handleDuplicate(on node: TimelineNode) {
        guard case .battle(_) = node.type else { return }
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.duplicateNode(id: node.id)
    }
    
    private func handleDelete(on node: TimelineNode) {
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.deleteNode(id: node.id)
    }
    
    private func handleMove(node: TimelineNode, direction: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            guard let currentIndex = daySession.nodes.firstIndex(where: { $0.id == node.id }) else { return }
            let newIndex = currentIndex + direction
            guard newIndex >= 0 && newIndex < daySession.nodes.count else { return }
            
            let sourceIndexSet = IndexSet(integer: currentIndex)
            let destinationIndex = newIndex > currentIndex ? newIndex + 1 : newIndex
            
            viewModel.moveNode(from: sourceIndexSet, to: destinationIndex)
        }
    }
}
