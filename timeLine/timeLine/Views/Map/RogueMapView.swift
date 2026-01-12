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
    @State private var selectedNodeId: UUID?
    
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
                Button(action: { showStats = true }) {
                    Image(systemName: "gearshape.fill")
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
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(Array(daySession.nodes.enumerated()), id: \.element.id) { index, node in
                    TimelineNodeRow(
                        node: node,
                        index: index,
                        isSelected: false,
                        isCurrent: node.id == daySession.currentNode?.id && isSessionActive,
                        onTap: { 
                            handleTap(on: node) 
                        },
                        onEdit: { handleEdit(on: node) },
                        timeInfo: timeInfo(for: node)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
    

    
    // MARK: - Helper Properties
    
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
        if !isSessionActive {
            return 0.5
        }
        guard viewportHeight > 0 else { return 0.82 }
        let anchor = 1 - (bottomFocusPadding / viewportHeight) - (bottomSheetInset / viewportHeight)
        return min(0.9, max(0.7, anchor))
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
        guard case .battle(_) = node.type else { return }
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
            
            let sourceIndexSet = IndexSet(integer: currentIndex)
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