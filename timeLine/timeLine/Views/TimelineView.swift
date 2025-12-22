import SwiftUI
import TimeLineCore
import Combine
import UIKit



// MARK: - Main View
struct TimelineView: View {
    // Cached formatter to avoid recreating DateFormatter repeatedly
    private struct Formatters {
        static let time: DateFormatter = {
            let f = DateFormatter()
            f.setLocalizedDateFormatFromTemplate("Hm")
            return f
        }()
    }
    
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var coordinator: TimelineEventCoordinator
    
    @State private var showRoutinePicker = false
    @State private var showingEditSheet = false
    @State private var templateToEdit: TaskTemplate?
    @State private var editingNodeId: UUID?
    
    @State private var draggingNodeId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartIndex: Int?
    @State private var rowHeights: [UUID: CGFloat] = [:]
    
    @State private var banner: BannerData?
    @State private var pulseNextNodeId: UUID?
    @State private var pulseClearTask: DispatchWorkItem?
    
    @State private var showFinished: Bool = false
    
    // Drag Optimization & Interaction Locking
    @State private var cachedRowHeights: [UUID: CGFloat]?
    @State private var isInteractionLocked: Bool = false
    
    private var finishedNodes: [TimelineNode] { daySession.nodes.filter { $0.isCompleted } }
    private var upcomingNodes: [TimelineNode] { daySession.nodes.filter { !$0.isCompleted } }
    
    var body: some View {
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
                
                // Section Header - Simple title only
                HStack {
                    Text("YOUR JOURNEY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(1.2)
                    Spacer()
                }
                .padding(.horizontal, TimelineLayout.horizontalInset)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Current time + upcoming label
                TimelineUpcomingLabel()
                    .padding(.horizontal, TimelineLayout.horizontalInset)
                    .padding(.bottom, 8)
                
                // Upcoming Nodes List
                UpcomingNodeListView(
                    upcomingNodes: upcomingNodes,
                    draggingNodeId: draggingNodeId,
                    dragOffset: dragOffset,
                    pulseNextNodeId: pulseNextNodeId,
                    isInteractionLocked: isInteractionLocked,
                    rowHeights: $rowHeights,
                    handleDragChanged: handleDragChanged,
                    handleDragEnded: handleDragEnded,
                    handleTap: handleTap,
                    startEditing: startEditing,
                    estimatedStartTime: estimatedStartTime
                )

                

                
                // Deck Bar Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("ADD TO JOURNEY")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(.cyan.opacity(0.8))
                        Spacer()
                    }
                    .padding(.horizontal, TimelineLayout.horizontalInset)
                    
                    HStack {
                        Button(action: { showRoutinePicker = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.cyan)
                                Text("ROUTINE PACKS")
                                    .font(.system(.caption, design: .rounded))
                                    .bold()
                                    .tracking(2)
                                    .foregroundColor(.cyan)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.cyan)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.cyan.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, TimelineLayout.horizontalInset)
                        Spacer()
                    }
                    
                    DeckBar()
                        .environmentObject(templateStore)
                        .environmentObject(daySession)
                        .environmentObject(stateManager)
                        .padding(.leading, 24)
                }
                .padding(.vertical, 24)
                
                Color.clear.frame(height: 60)
            }
        }
        .coordinateSpace(name: "scroll")
        .safeAreaInset(edge: .top) {
            HeaderView(focusedMinutes: Int(engine.totalFocusedToday / 60), progress: daySession.completionProgress)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $showRoutinePicker) {
            RoutinePickerView()
                .environmentObject(daySession)
                .environmentObject(stateManager)
        }
        .sheet(isPresented: $showingEditSheet) {
            TaskSheet(templateToEdit: $templateToEdit, isEditingNode: true) { updatedTemplate in
                if let id = editingNodeId {
                    daySession.updateNode(id: id, payload: updatedTemplate)
                    stateManager.requestSave()
                }
                editingNodeId = nil
                templateToEdit = nil
            }
        }
        .onReceive(coordinator.uiEvents) { event in
            handleUIEvent(event)
        }
        .overlay(alignment: .top) {
            if let banner = banner {
                InfoBanner(data: banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                if self.banner?.id == banner.id { self.banner = nil }
                            }
                        }
                    }
            }
        }
        // Removed overlay and blur - they were causing visual issues
    }
    
    // Estimate each upcoming node's start time based on current time and cumulative durations ahead of it.
    private func estimatedStartTime(for node: TimelineNode) -> (absolute: String, relative: String?)? {
        // Build a list of upcoming nodes in current order
        let nodes = upcomingNodes
        guard let idx = nodes.firstIndex(where: { $0.id == node.id }) else { return nil }

        var secondsAhead: TimeInterval = 0

        // If there is an active current node, account for remaining time instead of full duration
        if let current = daySession.currentNode, let currentIndex = nodes.firstIndex(where: { $0.id == current.id }) {
            if currentIndex < idx {
                switch current.type {
                case .battle(let boss):
                    // Estimate remaining time based on engine state if possible; fallback to full duration
                    let remaining: TimeInterval
                    switch engine.state {
                    case .fighting:
                        remaining = boss.maxHp
                    case .paused, .idle:
                        remaining = boss.maxHp
                    case .resting:
                        remaining = boss.maxHp
                    default:
                        remaining = boss.maxHp
                    }
                    secondsAhead += remaining
                case .bonfire(let dur):
                    let remaining: TimeInterval
                    switch engine.state {
                    case .resting:
                        remaining = dur
                    case .paused, .idle, .fighting:
                        remaining = dur
                    default:
                        remaining = dur
                    }
                    secondsAhead += remaining
                case .treasure:
                    break
                }
            }
        }

        // Sum durations of nodes before this one (in upcoming list), skipping current if already handled
        for i in 0..<idx {
            let n = nodes[i]
            if let current = daySession.currentNode, n.id == current.id {
                // already accounted for remaining time above
                continue
            }
            switch n.type {
            case .battle(let boss): secondsAhead += boss.maxHp
            case .bonfire(let dur): secondsAhead += dur
            case .treasure: break
            }
        }

        let startDate = Date().addingTimeInterval(secondsAhead)
        let absolute = Formatters.time.string(from: startDate)

        let remaining = Int(secondsAhead)
        let minutes = remaining / 60
        let seconds = remaining % 60
        let relative: String?
        if minutes > 0 {
            relative = "in \(minutes)m"
        } else if seconds > 0 {
            relative = "in \(seconds)s"
        } else {
            relative = nil
        }
        return (absolute, relative)
    }
    
    // MARK: - Drag Gesture (triggered from handle)
    // MARK: - Drag Gesture (triggered from handle)
    private func dragGestureStart(for node: TimelineNode) {
        // Freeze row heights at start of drag
        cachedRowHeights = rowHeights
        
        withAnimation(.spring(response: 0.2)) {
            draggingNodeId = node.id
            dragStartIndex = daySession.nodes.firstIndex(where: { $0.id == node.id })
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func handleDragChanged(_ value: DragGesture.Value, for node: TimelineNode) {
        // Ensure we mark the drag source once
        if draggingNodeId != node.id {
            dragGestureStart(for: node)
        }
        guard let startIndex = dragStartIndex else { return }

        // Use frozen heights if available, otherwise current
        let heights = cachedRowHeights ?? rowHeights
        
        // Use average row height if specific height missing
        let avgHeight: CGFloat = heights.values.isEmpty ? TimelineLayout.defaultRowHeight : (heights.values.reduce(0, +) / CGFloat(heights.values.count))
        let rowHeightRaw = heights[node.id] ?? avgHeight
        let rowHeight = max(1, rowHeightRaw)

        // Compute target from the original startIndex (prevents oscillation)
        let offsetRows = Int((value.translation.height / rowHeight).rounded(.toNearestOrAwayFromZero))
        let clampedTarget = max(0, min(daySession.nodes.count - 1, startIndex + offsetRows))
        let currentIndex = daySession.nodes.firstIndex(where: { $0.id == node.id }) ?? startIndex

        // Adjust the visual offset so the cell stays under the finger
        let stepsMoved = clampedTarget - startIndex
        let adjustedY = value.translation.height - CGFloat(stepsMoved) * rowHeight
        dragOffset = CGSize(width: value.translation.width, height: adjustedY)

        if clampedTarget != currentIndex {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                daySession.moveNode(from: IndexSet(integer: currentIndex), to: clampedTarget > currentIndex ? clampedTarget + 1 : clampedTarget)
            }
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value, for node: TimelineNode) {
        // Clear frozen heights
        cachedRowHeights = nil
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            draggingNodeId = nil
            dragOffset = .zero
            dragStartIndex = nil
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // Force update: Ensure currentNode is still valid after reordering
        if let currentNode = daySession.currentNode {
            // Verify current node still exists and update its index
            if let newIndex = daySession.nodes.firstIndex(where: { $0.id == currentNode.id }) {
                daySession.currentIndex = newIndex
            }
        }
        
        // Save after drag completes
        stateManager.requestSave()
        
        // Lock interaction briefly to prevent accidental taps
        isInteractionLocked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isInteractionLocked = false
        }

    }
    
    private func handleTap(on node: TimelineNode) {
        // Block taps if interaction is locked (e.g., right after drag)
        guard !isInteractionLocked else { return }
        guard !node.isLocked, !node.isCompleted else { 
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return 
        }
        
        switch node.type {
        case .battle(let boss):
            if node.id != daySession.currentNode?.id {
                // Switching to a new task
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                daySession.setCurrentNode(id: node.id)
                engine.startBattle(boss: boss)
                stateManager.requestSave()
            } else {
                // Tapping the already active task
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
            let temp = TaskTemplate(
                id: boss.id,
                title: boss.name,
                style: boss.style,
                duration: boss.maxHp,
                repeatRule: .none,
                category: boss.category
            )
            self.templateToEdit = temp
            self.editingNodeId = node.id
            self.showingEditSheet = true
            
        case .bonfire(let duration):
            let temp = TaskTemplate(
                id: node.id,
                title: "Rest",
                style: .passive,
                duration: duration,
                repeatRule: .none,
                category: .rest
            )
            self.templateToEdit = temp
            self.editingNodeId = node.id
            self.showingEditSheet = true
            
        case .treasure:
            // Treasure nodes are system-generated and cannot be edited
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                banner = BannerData(kind: .distraction(wastedMinutes: 0), upNextTitle: "系统节点无法编辑")
            }
        }
    }
    
    // MARK: - UI Event Handling
    private func resolveUpNext(after node: TimelineNode?) -> (node: TimelineNode?, title: String?) {
        let nodes = daySession.nodes
        guard !nodes.isEmpty else { return (nil, nil) }
        let startIndex: Int
        if let node = node, let idx = nodes.firstIndex(where: { $0.id == node.id }) {
            startIndex = idx + 1
        } else if let current = daySession.currentNode, let idx = nodes.firstIndex(where: { $0.id == current.id }) {
            startIndex = idx + 1
        } else {
            startIndex = 0
        }
        for i in startIndex..<nodes.count {
            let n = nodes[i]
            switch n.type {
            case .treasure:
                continue
            case .bonfire(let duration):
                let minutes = max(1, Int(duration / 60))
                return (n, "Rest (\(minutes)m)")
            case .battle(let boss):
                let minutes = max(1, Int(boss.maxHp / 60))
                return (n, "\(boss.name) (\(minutes)m)")
            }
        }
        return (nil, nil)
    }

    private func handleUIEvent(_ event: TimelineUIEvent) {
        let resolved = resolveUpNext(after: daySession.currentNode)
        switch event {
        case .victory(_, _):
            // Only pulse next to keep flow lightweight
            pulseNext(nodeId: resolved.node?.id)
        case .retreat(_, let wastedMinutes):
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                banner = BannerData(kind: .distraction(wastedMinutes: wastedMinutes), upNextTitle: resolved.title)
                pulseNextNodeId = resolved.node?.id
            }
            schedulePulseClear()
        case .bonfireComplete:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                banner = BannerData(kind: .restComplete, upNextTitle: resolved.title)
                pulseNextNodeId = resolved.node?.id
            }
            schedulePulseClear()
        }
    }

    private func pulseNext(nodeId: UUID?) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            self.pulseNextNodeId = nodeId
        }
        schedulePulseClear()
    }

    private func schedulePulseClear() {
        pulseClearTask?.cancel()
        let task = DispatchWorkItem { [self] in
            withAnimation(.easeInOut(duration: 0.3)) {
                pulseNextNodeId = nil
            }
        }
        pulseClearTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }
}


