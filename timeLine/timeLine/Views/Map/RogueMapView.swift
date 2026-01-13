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
    
    // View Model
    @StateObject private var viewModel = MapViewModel()
    
    @AppStorage("use24HourClock") private var use24HourClock = true
    
    @State private var showStats = false
    @State private var nodeAnchors: [UUID: CGFloat] = [:]
    @State private var nodeFrames: [UUID: CGRect] = [:]
    @State private var viewportHeight: CGFloat = 0
    @State private var showNodeEdit = false
    @State private var showNodeActionMenu = false
    @State private var editingNodeTemplate: CardTemplate?
    @State private var editingNodeId: UUID?
    @State private var selectedNodeId: UUID?
    @State private var actionMenuNode: TimelineNode?
    @State private var isEditMode = false
    
    private let bottomFocusPadding: CGFloat = 140
    private let bottomSheetInset: CGFloat = 96
    
    private var upcomingNodes: [TimelineNode] { daySession.nodes.filter { !$0.isCompleted } }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background
                Color(red: 0.95, green: 0.94, blue: 0.92)
                    .ignoresSafeArea()
                
                // Main timeline view
                VStack(spacing: 0) {
                    // Header
                    timelineHeader
                    
                    // Timeline scroll view
                    timelineScrollView
                }
            }
            .onAppear {
                // Bind viewModel to dependencies for time calculations
                viewModel.bind(
                    engine: engine,
                    daySession: daySession,
                    stateManager: stateManager,
                    cardStore: cardStore,
                    use24HourClock: use24HourClock
                )
            }
            .onChange(of: use24HourClock) { _, newValue in
                // Update viewModel preferences when clock format changes
                viewModel.updatePreferences(use24HourClock: newValue)
            }
            .sheet(isPresented: $showStats) {
                AdventurerLogView()
            }
            .sheet(isPresented: $showNodeEdit) {
                TaskSheet(
                    templateToEdit: $editingNodeTemplate,
                    isEditingNode: true,
                    onSaveNode: { template in
                        guard let nodeId = editingNodeId else { return }
                        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
                        if template.remindAt != nil {
                            timelineStore.updateNodeByTime(id: nodeId, payload: template, engine: engine)
                        } else {
                            timelineStore.updateNode(id: nodeId, payload: template)
                        }
                    }
                )
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
            return "Rest Point"
        case .treasure:
            return "Treasure"
        }
    }
    
    // MARK: - Timeline Header
    
    private var timelineHeader: some View {
        VStack(spacing: 0) {
            // Chapter header
            HStack {
                Image(systemName: "book.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                Text("CHAPTER \(currentChapter)")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                Spacer()
                
                // Edit button
                Button(action: { isEditMode.toggle() }) {
                    Text(isEditMode ? "Done" : "Edit")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(PixelTheme.primary)
                }
                
                Button(action: { showStats = true }) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Journey title and progress
            VStack(alignment: .leading, spacing: 8) {
                Text(journeyTitle)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.1))
                
                HStack {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.7))
                    Text("\(Int(engine.totalFocusedToday / 60))m")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.7))
                    
                    Spacer()
                    
                    Text("LEVEL \(currentLevel)")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                }
                
                // Progress bar
                ProgressView(value: daySession.completionProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 1.0, green: 0.6, blue: 0.2)))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Timeline Scroll View
    
    private var timelineScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(daySession.nodes.reversed()) { node in
                        TimelineNodeRow(
                            node: node,
                            index: daySession.nodes.firstIndex(where: { $0.id == node.id }) ?? 0,
                            isSelected: false,
                            isCurrent: shouldShowAsCurrentTask(node: node),
                            isEditMode: isEditMode,
                            onTap: { handleTap(on: node) },
                            onEdit: { handleEdit(on: node) },
                            onDuplicate: { handleDuplicate(on: node) },
                            onDelete: { handleDelete(on: node) },
                            onMoveUp: { handleMove(node: node, direction: -1) },
                            onMoveDown: { handleMove(node: node, direction: 1) },
                            onDrop: { _ in }, // Drop handling is centralized in RootView
                            totalNodesCount: daySession.nodes.count,
                            contentOffset: offsetForNode(node),
                            estimatedTimeLabel: estimatedTimeLabel(for: node)
                        )
                        // .offset(y: offsetForNode(node)) -> Moved inside TimelineNodeRow to keep axis stationary
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragCoordinator.hoveringNodeId)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragCoordinator.hoveringPlacement)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .id(node.id) // Add ID for scrollTo
                    }
                }
                .frame(maxWidth: .infinity) // Expand content to full width for better scrolling
            }
            .scrollDisabled(appMode.isDragging) // Disable scroll when dragging a node
            .contentShape(Rectangle()) // Make entire scroll area interactive
            .animation(.easeInOut(duration: 0.3), value: daySession.nodes.count)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: daySession.nodes.map(\.id))
            .onPreferenceChange(NodeFrameKey.self) { frames in
                nodeFrames = frames
            }
            .onChange(of: dragCoordinator.dragLocation) { _, newLocation in
                // Update position when drag location changes
                if dragCoordinator.activePayload != nil {
                    let allowedNodeIds = Set(daySession.nodes.map(\.id))
                    dragCoordinator.updatePosition(
                        newLocation,
                        nodeFrames: nodeFrames,
                        allowedNodeIds: allowedNodeIds
                    )
                }
            }
            .onChange(of: daySession.nodes.count) { _, _ in
                // Auto-scroll to current task when nodes are added/removed
                scrollToActive(using: proxy)
            }
            .onChange(of: daySession.currentIndex) { _, _ in
                // Auto-scroll when current task changes
                scrollToActive(using: proxy)
            }
            .onAppear {
                // Initial scroll to current task
                scrollToActive(using: proxy)
            }
        }
    }
    
    private func moveNodes(from source: IndexSet, to destination: Int) {
        // Wrap the move operation in animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // List displays nodes in reversed order, so we need to convert indices
            // Display order: reversed (last node displayed first)
            // Data order: normal (first node at index 0)
            
            let nodeCount = daySession.nodes.count
            guard let sourceIndex = source.first else { return }
            
            // Convert from reversed display index to actual data index
            let actualSourceIndex = nodeCount - 1 - sourceIndex
            
            // Destination index conversion is tricky because of how List.onMove works
            // If moving down in display (up in data), destination needs adjustment
            let actualDestination: Int
            if destination > sourceIndex {
                // Moving down in display = moving up in data
                actualDestination = nodeCount - destination
            } else {
                // Moving up in display = moving down in data
                actualDestination = nodeCount - destination
            }
            
            // Perform the move
            let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
            timelineStore.moveNode(from: IndexSet(integer: actualSourceIndex), to: actualDestination)
        }
    }
    

    
    // MARK: - Helper Properties
    
    private func offsetForNode(_ node: TimelineNode) -> CGFloat {
        // If no drag is active, no offset
        guard let draggedNodeId = dragCoordinator.draggedNodeId,
              let hoveringNodeId = dragCoordinator.hoveringNodeId,
              draggedNodeId != node.id else {
            return 0
        }
        
        // SWAP BEHAVIOR: Only the node being hovered over moves to the dragged node's original position
        // Other nodes stay in place
        
        // Only apply offset to the node we're hovering over
        guard node.id == hoveringNodeId else {
            return 0
        }
        
        // Get indices for calculations
        guard let draggedIndex = daySession.nodes.firstIndex(where: { $0.id == draggedNodeId }),
              let hoveringIndex = daySession.nodes.firstIndex(where: { $0.id == hoveringNodeId }) else {
            return 0
        }
        
        // Calculate the height to offset (dragged card's height)
        let draggedCardHeight: CGFloat = shouldShowAsCurrentTask(node: daySession.nodes[draggedIndex]) ? 200 : 80
        let spacing: CGFloat = 20
        let totalOffset = draggedCardHeight + spacing
        
        // The hovered node should move toward the dragged node's original position
        // In reversed display:
        // - Higher data index = higher visual position (top)
        // - Lower data index = lower visual position (bottom)
        //
        // If dragged is above hovered (draggedIndex > hoveringIndex in data = dragged is higher visually)
        // → hovered node should move UP (negative offset in our coordinate system)
        //
        // If dragged is below hovered (draggedIndex < hoveringIndex)
        // → hovered node should move DOWN (positive offset)
        
        if draggedIndex > hoveringIndex {
            // Dragged node was visually above → move hovered node UP
            return -totalOffset
        } else if draggedIndex < hoveringIndex {
            // Dragged node was visually below → move hovered node DOWN
            return totalOffset
        }
        
        return 0
    }
    
    private func shouldShowAsCurrentTask(node: TimelineNode) -> Bool {
        // Only show the next upcoming (non-completed) task as large
        // Don't show active session task as large unless it's also the next upcoming
        let firstUpcoming = upcomingNodes.first
        return node.id == firstUpcoming?.id
    }
    
    private var currentChapter: Int {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        return weekOfYear
    }
    
    private var currentLevel: Int {
        let totalHours = Int(engine.totalFocusedToday / 3600)
        return max(1, totalHours + 1)
    }
    
    private var journeyTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: Date())
        return "The \(dayName) Dungeon"
    }
    
    private var isSessionActive: Bool {
        switch engine.state {
        case .fighting, .paused, .frozen, .resting:
            return true
        default:
            return false
        }
    }
    
    private var currentActiveId: UUID? {
        isSessionActive ? daySession.currentNode?.id : nil
    }
    
    private var mapAnchorY: CGFloat {
        // Anchor point for scrolling: 0.0 = top, 1.0 = bottom
        // Using 0.35 to position NOW task in upper-middle area (not too high, not too low)
        if !isSessionActive {
            return 0.35  // NOW task at ~35% from top when not in session
        }
        guard viewportHeight > 0 else { return 0.35 }
        let anchor = 1 - (bottomFocusPadding / viewportHeight) - (bottomSheetInset / viewportHeight)
        return min(0.45, max(0.3, anchor))  // Keep between 30-45% from top
    }
    
    // MARK: - Action Handlers
    
    private func handleTap(on node: TimelineNode) {
        guard !node.isCompleted else {
            Haptics.impact(.light)
            return
        }

        if case .battle = node.type {
            let behavior = node.effectiveTaskBehavior { id in
                cardStore.get(id: id)
            }
            if behavior == .reminder {
                coordinator.completeReminder(nodeId: node.id)
                Haptics.impact(.medium)
                return
            }
        }

        let isFirstUpcoming = upcomingNodes.first?.id == node.id
        if !isSessionActive && isFirstUpcoming {
            // Allow start even if lock state is stale.
        } else {
            guard !node.isLocked, !node.isCompleted else {
                Haptics.impact(.light)
                return
            }
        }
        
        switch node.type {
        case .battle(let boss):
            if node.id != daySession.currentNode?.id {
                Haptics.impact(.medium)
                daySession.setCurrentNode(id: node.id)
                engine.startBattle(boss: boss)
                stateManager.requestSave()
            } else {
                if engine.state == .frozen {
                    engine.resumeFromFreeze()
                    stateManager.requestSave()
                } else if engine.state != .fighting {
                    engine.startBattle(boss: boss)
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
        if let templateId = boss.templateId, let template = cardStore.get(id: templateId) {
            editingNodeTemplate = template
        } else {
            editingNodeTemplate = CardTemplate(
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
        }
        editingNodeId = node.id
        showNodeEdit = true
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
    
    private func handleDrop(action: DropAction) {
        switch action {
        case .moveNode(let nodeId, let anchorId, let placement):
            guard let currentIndex = daySession.nodes.firstIndex(where: { $0.id == nodeId }),
                  let anchorIndex = daySession.nodes.firstIndex(where: { $0.id == anchorId }) else { return }
            
            let destinationIndex: Int
            // Since list is reversed:
            // .before (Visual Top) -> Higher Index -> Insert at anchorIndex + 1
            // .after (Visual Bottom) -> Lower Index -> Insert at anchorIndex
            if placement == .before {
                destinationIndex = anchorIndex + 1
            } else {
                destinationIndex = anchorIndex
            }
            
            // Don't move if it's the same position
            guard destinationIndex != currentIndex && destinationIndex != currentIndex + 1 else { return }
            
            let sourceIndexSet = IndexSet(integer: currentIndex)
            
            // Execute move without explicit animation block (let view animation handle it)
            viewModel.moveNode(from: sourceIndexSet, to: destinationIndex)
            
            Haptics.impact(.medium)
            
        case .placeCard(_, _, _):
            Haptics.impact(.light)
        default:
            break
        }
    }
    
    private func timeInfo(for node: TimelineNode) -> MapTimeInfo? {
        if case .battle(let boss) = node.type, boss.recommendedStart != nil, boss.remindAt == nil {
            return MapTimeInfo(absolute: nil, relative: nil, isRecommended: true)
        }
        guard let estimate = viewModel.estimatedStartTime(for: node, upcomingNodes: upcomingNodes) else { return nil }
        return MapTimeInfo(
            absolute: estimate.absolute,
            relative: estimate.relative,
            isRecommended: false
        )
    }
    
    private func estimatedTimeLabel(for node: TimelineNode) -> String? {
        // Don't show time for current or completed tasks
        guard !node.isCompleted else { return nil }
        guard !shouldShowAsCurrentTask(node: node) else { return nil }
        
        // Calculate time directly without viewModel
        // Get the index of this node in upcomingNodes
        guard let nodeIndex = upcomingNodes.firstIndex(where: { $0.id == node.id }) else {
            return nil
        }
        
        // Calculate cumulative time from current task to this node
        var secondsFromNow: TimeInterval = 0
        
        // If there's a current task and it has remaining time, add that first
        if let currentNode = upcomingNodes.first {
            // Add remaining time of current task (estimate or full duration)
            if engine.state == .fighting, let remaining = engine.remainingTime {
                secondsFromNow += remaining
            } else {
                secondsFromNow += duration(for: currentNode)
            }
        }
        
        // Add durations of all tasks between first (current) and this node
        for i in 1..<nodeIndex {
            secondsFromNow += duration(for: upcomingNodes[i])
        }
        
        // Calculate estimated start time
        let estimatedTime = Date().addingTimeInterval(secondsFromNow)
        
        // Format as time string (e.g., "8:30 PM" or "20:30")
        let formatter = DateFormatter()
        formatter.dateFormat = use24HourClock ? "HH:mm" : "h:mm a"
        return formatter.string(from: estimatedTime)
    }
    
    private func duration(for node: TimelineNode) -> TimeInterval {
        switch node.type {
        case .battle(let boss):
            return boss.maxHp
        case .bonfire(let dur):
            return dur
        case .treasure:
            return 0
        }
    }
    
    private func scrollToActive(using proxy: ScrollViewProxy) {
        let targetId = isSessionActive ? daySession.currentNode?.id : upcomingNodes.first?.id
        guard let targetId else { return }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                proxy.scrollTo(targetId, anchor: UnitPoint(x: 0.5, y: mapAnchorY))
            }
        }
    }
    
    private func snapToNearestNode(using proxy: ScrollViewProxy) {
        guard !nodeAnchors.isEmpty else { return }
        let targetY = viewportHeight * mapAnchorY
        let nearest = nodeAnchors.min { lhs, rhs in
            abs(lhs.value - targetY) < abs(rhs.value - targetY)
        }
        guard let id = nearest?.key else { return }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: mapAnchorY))
            }
        }
    }
}

private struct PixelMapBackground: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1. Base Layer
            PixelTheme.background
                .ignoresSafeArea()
            
            // 2. Vertical Dashed Line
            Path { path in
                path.move(to: CGPoint(x: 68, y: 0))
                path.addLine(to: CGPoint(x: 68, y: 3000))
            }
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 10]))
            .fill(PixelTheme.pathPixel)
            .ignoresSafeArea()
        }
    }
}