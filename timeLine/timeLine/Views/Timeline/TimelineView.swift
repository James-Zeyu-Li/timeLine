import SwiftUI
import TimeLineCore
import Combine
import UIKit

// MARK: - Main View
struct TimelineView: View {
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var coordinator: TimelineEventCoordinator
    @EnvironmentObject var appMode: AppModeManager
    
    // View Model
    @StateObject private var viewModel = TimelineViewModel()
    
    @AppStorage("use24HourClock") private var use24HourClock = true
    
    @State private var showStats = false
    @State private var showingEditSheet = false
    @State private var templateToEdit: CardTemplate?
    @State private var editingNodeId: UUID?
    private let bottomSheetInset: CGFloat = 96
    
    @State private var draggingNodeId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartIndex: Int?
    @State private var rowHeights: [UUID: CGFloat] = [:]
    
    @State private var showFinished: Bool = false
    @State private var isEditMode: Bool = false
    
    // Drag Optimization & Interaction Locking
    @State private var cachedRowHeights: [UUID: CGFloat]?
    @State private var isInteractionLocked: Bool = false
    
    private var finishedNodes: [TimelineNode] { daySession.nodes.filter { $0.isCompleted } }
    private var upcomingNodes: [TimelineNode] { daySession.nodes.filter { !$0.isCompleted } }
    
    var body: some View {
        ZStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    // Pull-down probe for revealing Finished section
                    PullDownProbeView(showFinished: $showFinished, hasFinishedNodes: !finishedNodes.isEmpty)
                        .frame(height: 1)
                    
                    // Finished Section
                    if !finishedNodes.isEmpty {
                        FinishedSectionView(
                            finishedNodes: finishedNodes,
                            showFinished: $showFinished
                        )
                    }
                    
                    TimelineSectionHeader(isEditMode: $isEditMode)
                    
                    // Current time + upcoming label
                    TimelineUpcomingLabel(timeText: TimeFormatter.formatClock(Date(), use24Hour: use24HourClock))
                        .padding(.horizontal, TimelineLayout.horizontalInset)
                        .padding(.bottom, 8)
                    
                    // Upcoming Nodes List
                    UpcomingNodeListView(
                        upcomingNodes: upcomingNodes,
                        draggingNodeId: draggingNodeId,
                        dragOffset: dragOffset,
                        pulseNextNodeId: viewModel.pulseNextNodeId,
                        isInteractionLocked: isInteractionLocked,
                        currentActiveId: currentActiveId,
                        isEditMode: isEditMode,
                        rowHeights: $rowHeights,
                        handleDragChanged: handleDragChanged,
                        handleDragEnded: handleDragEnded,
                        handleTap: handleTap,
                        startEditing: startEditing,
                        estimatedStartTime: { node in
                            viewModel.estimatedStartTime(for: node, upcomingNodes: upcomingNodes)
                        }
                    )

                    // Inbox (Tomorrow / Later)
                    let inboxTemplates = stateManager.inbox.compactMap { cardStore.get(id: $0) }
                    if !inboxTemplates.isEmpty {
                        InboxListView(
                            items: inboxTemplates,
                            onAdd: { item in viewModel.addInboxItem(item) },
                            onRemove: { item in viewModel.removeInboxItem(item.id) }
                        )
                            .padding(.horizontal, TimelineLayout.horizontalInset)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.bottom, bottomSheetInset)
            }
            .coordinateSpace(name: "scroll")
            
        }
        .safeAreaInset(edge: .top) {
            HeaderView(
                focusedMinutes: Int(engine.totalFocusedToday / 60),
                progress: daySession.completionProgress,
                onDayTap: { showStats = true }
            )
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $showStats) {
            StatsView()
        }
        .sheet(isPresented: $showingEditSheet) {
            TaskSheet(templateToEdit: $templateToEdit, isEditingNode: true) { updatedTemplate in
                if let id = editingNodeId {
                    let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
                    timelineStore.updateNode(id: id, payload: updatedTemplate)
                }
                editingNodeId = nil
                templateToEdit = nil
            }
        }
        .onReceive(coordinator.uiEvents) { event in
            viewModel.handleUIEvent(event)
        }
        .onAppear {
                viewModel.bind(
                    engine: engine,
                    daySession: daySession,
                    stateManager: stateManager,
                    cardStore: cardStore,
                    use24HourClock: use24HourClock
                )
            
            if !isSessionActive {
                daySession.resetCurrentToFirstUpcoming()
            }
        }
        .onChange(of: use24HourClock) { _, newValue in
            viewModel.updatePreferences(use24HourClock: newValue)
        }
        .onChange(of: engine.state) { _, newState in
            switch newState {
            case .idle, .victory, .retreat:
                daySession.resetCurrentToFirstUpcoming()
            default:
                break
            }
        }
        .overlay(alignment: .top) {
            if let banner = viewModel.banner {
                InfoBanner(data: banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: viewModel.banner)
    }

    private var isSessionActive: Bool {
        switch engine.state {
        case .fighting, .paused, .resting:
            return true
        default:
            return false
        }
    }

    private var currentActiveId: UUID? {
        isSessionActive ? daySession.currentNode?.id : nil
    }
    
    // MARK: - Drag Gesture (triggered from handle)
    private func dragGestureStart(for node: TimelineNode) {
        cachedRowHeights = rowHeights
        withAnimation(.spring(response: 0.2)) {
            draggingNodeId = node.id
            dragStartIndex = daySession.nodes.firstIndex(where: { $0.id == node.id })
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func handleDragChanged(_ value: DragGesture.Value, for node: TimelineNode) {
        if draggingNodeId != node.id {
            dragGestureStart(for: node)
        }
        guard let startIndex = dragStartIndex else { return }

        let heights = cachedRowHeights ?? rowHeights
        let avgHeight: CGFloat = heights.values.isEmpty ? TimelineLayout.defaultRowHeight : (heights.values.reduce(0, +) / CGFloat(heights.values.count))
        let rowHeightRaw = heights[node.id] ?? avgHeight
        let rowHeight = max(1, rowHeightRaw)

        let offsetRows = Int((value.translation.height / rowHeight).rounded(.toNearestOrAwayFromZero))
        let clampedTarget = max(0, min(daySession.nodes.count - 1, startIndex + offsetRows))
        let currentIndex = daySession.nodes.firstIndex(where: { $0.id == node.id }) ?? startIndex

        let stepsMoved = clampedTarget - startIndex
        let adjustedY = value.translation.height - CGFloat(stepsMoved) * rowHeight
        dragOffset = CGSize(width: value.translation.width, height: adjustedY)

        if clampedTarget != currentIndex {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                viewModel.moveNode(from: IndexSet(integer: currentIndex), to: clampedTarget > currentIndex ? clampedTarget + 1 : clampedTarget)
            }
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value, for node: TimelineNode) {
        resetDragState()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        let activeNodeId = isSessionActive ? daySession.currentNode?.id : nil
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.finalizeReorder(isSessionActive: isSessionActive, activeNodeId: activeNodeId)
        isInteractionLocked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isInteractionLocked = false
        }
    }

    private func resetDragState() {
        cachedRowHeights = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            draggingNodeId = nil
            dragOffset = .zero
            dragStartIndex = nil
        }
    }
    
    private func handleTap(on node: TimelineNode) {
        guard !isInteractionLocked else { return }
        guard !isEditMode else { return }
        
        let isFirstUpcoming = upcomingNodes.first?.id == node.id
        if !isSessionActive && isFirstUpcoming {
            // Allow starting the first task even if lock state is stale
        } else {
            guard !node.isLocked, !node.isCompleted else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                return
            }
        }
        guard !node.isCompleted else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return 
        }
        
        switch node.type {
        case .battle(let boss):
            if node.id != daySession.currentNode?.id {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                daySession.setCurrentNode(id: node.id)
                engine.startBattle(boss: boss)
                stateManager.requestSave()
            } else {
                if engine.state != .fighting {
                    engine.startBattle(boss: boss)
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        case .bonfire(let duration):
            if node.id != daySession.currentNode?.id {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
    
    private func startEditing(node: TimelineNode) {
        switch node.type {
        case .battle(let boss):
            let temp = CardTemplate(
                id: boss.id,
                title: boss.name,
                icon: boss.category.icon,
                defaultDuration: boss.maxHp,
                tags: [],
                energyColor: energyToken(for: boss.category),
                category: boss.category,
                style: boss.style
            )
            self.templateToEdit = temp
            self.editingNodeId = node.id
            self.showingEditSheet = true
            
        case .bonfire(let duration):
            let temp = CardTemplate(
                id: node.id,
                title: "Rest",
                icon: TaskCategory.rest.icon,
                defaultDuration: duration,
                tags: [],
                energyColor: energyToken(for: .rest),
                category: .rest,
                style: .passive
            )
            self.templateToEdit = temp
            self.editingNodeId = node.id
            self.showingEditSheet = true
            
        case .treasure:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                viewModel.banner = BannerData(kind: .distraction(wastedMinutes: 0), upNextTitle: "系统节点无法编辑")
            }
        }
    }

    private func energyToken(for category: TaskCategory) -> EnergyColorToken {
        switch category {
        case .work, .study:
            return .focus
        case .gym:
            return .gym
        case .rest:
            return .rest
        case .other:
            return .creative
        }
    }
}
