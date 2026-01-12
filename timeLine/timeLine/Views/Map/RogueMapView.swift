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
    @State private var editingNodeTemplate: CardTemplate?
    @State private var editingNodeId: UUID?
    
    private let bottomFocusPadding: CGFloat = 140
    private let bottomSheetInset: CGFloat = 96
    
    private var upcomingNodes: [TimelineNode] { daySession.nodes.filter { !$0.isCompleted } }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background: Map content
                mapContent(proxy: proxy)
            }
            .sheet(isPresented: $showStats) {
                StatsView()
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
        }
    }
    
    // MARK: - Map Content
    @ViewBuilder
    private func mapContent(proxy: GeometryProxy) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    mapTrack
                    
                    let inboxTemplates = stateManager.inbox.compactMap { cardStore.get(id: $0) }
                    if !inboxTemplates.isEmpty {
                        InboxListView(
                            items: inboxTemplates,
                            onAdd: { item in viewModel.addInboxItem(item) },
                            onRemove: { item in viewModel.removeInboxItem(item.id) }
                        )
                        .padding(.horizontal, MapLayout.horizontalInset)
                        .padding(.vertical, 16)
                    }
                }
                .padding(.top, 16)
                // Reserve space for collapsed bottom sheet
                .padding(.bottom, bottomSheetInset)
            }
            .coordinateSpace(name: "mapScroll")
            .safeAreaInset(edge: .top) {
                HeaderView(
                    focusedMinutes: Int(engine.totalFocusedToday / 60),
                    progress: daySession.completionProgress,
                    onDayTap: { showStats = true }
                )
            }
            .background(PixelMapBackground())
            .overlay(alignment: .top) {
                if let banner = viewModel.banner {
                    InfoBanner(data: banner)
                        .padding(.top, 6)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: viewModel.banner)
            .onPreferenceChange(MapNodeAnchorKey.self) { value in
                nodeAnchors = value
            }
            .onPreferenceChange(NodeFrameKey.self) { value in
                nodeFrames = value
            }
            .onChange(of: dragCoordinator.dragLocation) { _, newValue in
                guard dragCoordinator.activePayload != nil else { return }
                var allowedIds = Set(daySession.nodes.map(\.id))
                // Can filter allowedIds if needed (e.g. only unlock nodes?)
                // For now allow reordering any node
                dragCoordinator.updatePosition(newValue, nodeFrames: nodeFrames, allowedNodeIds: allowedIds)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { _ in
                        snapToNearestNode(using: scrollProxy)
                    }
            )
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
                
                viewportHeight = proxy.size.height
                scrollToActive(using: scrollProxy)
            }
            .onChange(of: use24HourClock) { _, newValue in
                viewModel.updatePreferences(use24HourClock: newValue)
            }
            .onChange(of: proxy.size.height) { _, newValue in
                viewportHeight = newValue
            }
            .onChange(of: daySession.currentIndex) { _, _ in
                scrollToActive(using: scrollProxy)
            }
            .onChange(of: engine.state) { _, _ in
                scrollToActive(using: scrollProxy)
            }
        }
    }

    private var mapTrack: some View {
        let nodes = Array(daySession.nodes.enumerated().reversed())
        let currentId = currentActiveId
        let nextId = upcomingNodes.first?.id
        
        return VStack(spacing: 26) {
            ForEach(nodes.indices, id: \.self) { offset in
                let item = nodes[offset]
                let index = item.offset
                let node = item.element
                let alignment: MapNodeAlignment = offset.isMultiple(of: 2) ? .left : .right
                let isCurrent = currentId == node.id
                let isNext = !isSessionActive && nextId == node.id
                let isFinal = index == daySession.nodes.indices.last
                let timeInfo = node.isCompleted ? nil : timeInfo(for: node)
                
                SwipeableTimelineNode(
                    node: node,
                    alignment: alignment,
                    isCurrent: isCurrent,
                    isNext: isNext,
                    isFinal: isFinal,
                    isPulsing: viewModel.pulseNextNodeId == node.id,
                    timeInfo: timeInfo,
                    onTap: { handleTap(on: node) },
                    onLongPress: { handleLongPress(on: node) },
                    onEdit: { handleEdit(on: node) },
                    onDuplicate: { handleDuplicate(on: node) },
                    onDelete: { handleDelete(on: node) },
                    onMove: { direction in handleMove(node: node, direction: direction) },
                    onDrop: { action in handleDrop(action: action) }
                )
                .id(node.id)
            }
        }
        .padding(.horizontal, MapLayout.horizontalInset)
        .padding(.bottom, bottomFocusPadding)
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
        if !isSessionActive {
            return 0.5
        }
        guard viewportHeight > 0 else { return 0.82 }
        let anchor = 1 - (bottomFocusPadding / viewportHeight) - (bottomSheetInset / viewportHeight)
        return min(0.9, max(0.7, anchor))
    }
    
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
        handleEdit(on: node)
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
        guard case .battle(let boss) = node.type else { return }
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.duplicateNode(id: node.id)
    }
    
    private func handleDelete(on node: TimelineNode) {
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.deleteNode(id: node.id)
    }
    
    private func handleMove(node: TimelineNode, direction: Int) {
        guard let currentIndex = daySession.nodes.firstIndex(where: { $0.id == node.id }) else { return }
        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < daySession.nodes.count else { return }
        
        // 使用IndexSet进行移动，确保正确的重排序
        let sourceIndexSet = IndexSet(integer: currentIndex)
        let destinationIndex = newIndex > currentIndex ? newIndex + 1 : newIndex
        
        viewModel.moveNode(from: sourceIndexSet, to: destinationIndex)
    }
    
    private func handleDrop(action: DropAction) {
        switch action {
        case .moveNode(let nodeId, let anchorId, let placement):
            guard let currentIndex = daySession.nodes.firstIndex(where: { $0.id == nodeId }),
                  let anchorIndex = daySession.nodes.firstIndex(where: { $0.id == anchorId }) else { return }
            
            let destinationIndex: Int
            if placement == .before {
                destinationIndex = anchorIndex
            } else {
                destinationIndex = anchorIndex + 1
            }
            
            // Adjust destination index if moving downwards (source < destination)
            // The standard move logic handles this, but let's be precise.
            // viewModel.moveNode uses the standard SwiftUI move logic where destination is insertion point.
            
            let sourceIndexSet = IndexSet(integer: currentIndex)
            viewModel.moveNode(from: sourceIndexSet, to: destinationIndex)
            
            Haptics.impact(.medium)
            
        case .placeCard(let cardTemplateId, let anchorNodeId, let placement):
            // Existing logic or delegate to viewModel
            Haptics.impact(.light)
            // Implement if needed for card drop
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
        GeometryReader { _ in
            ZStack {
                LinearGradient(
                    colors: [
                        PixelTheme.backgroundTop,
                        PixelTheme.backgroundBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Canvas { context, size in
                    let grid: CGFloat = PixelTheme.baseUnit * 5.5
                    let dot: CGFloat = 2
                    for y in stride(from: 0, through: size.height, by: grid) {
                        for x in stride(from: 0, through: size.width, by: grid) {
                            let rect = CGRect(x: x, y: y, width: dot, height: dot)
                            context.fill(Path(rect), with: .color(PixelTheme.backgroundGrid))
                        }
                    }
                    
                    let tile: CGFloat = PixelTheme.baseUnit * 2
                    for y in stride(from: grid * 0.6, to: size.height, by: grid * 2.6) {
                        for x in stride(from: grid * 0.5, to: size.width, by: grid * 2.8) {
                            let rect = CGRect(x: x, y: y, width: tile, height: tile)
                            context.fill(Path(rect), with: .color(PixelTheme.backgroundTile))
                        }
                    }
                }
                
                PixelTerrainBand()
                    .frame(height: 90)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .ignoresSafeArea()
    }
}

private struct PixelTerrainBand: View {
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let tile: CGFloat = PixelTheme.baseUnit * 3
                let rows = 3
                let baseColor = PixelTheme.forest
                for row in 0..<rows {
                    let y = size.height - CGFloat(row + 1) * tile
                    let opacity = 0.25 - (CGFloat(row) * 0.06)
                    for x in stride(from: 0, to: size.width, by: tile) {
                        let rect = CGRect(x: x, y: y, width: tile - 1, height: tile - 1)
                        context.fill(Path(rect), with: .color(baseColor.opacity(opacity)))
                    }
                }
            }
        }
    }
}
