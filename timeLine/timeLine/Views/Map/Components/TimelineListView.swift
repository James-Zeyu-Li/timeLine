import SwiftUI
import TimeLineCore

enum TimelineNodeAction {
    case tap(TimelineNode)
    case edit(TimelineNode)
    case duplicate(TimelineNode)
    case delete(TimelineNode)
    case moveUp(TimelineNode)
    case moveDown(TimelineNode)
}

struct TimelineListView: View {
    @ObservedObject var viewModel: MapViewModel
    let onAction: (TimelineNodeAction) -> Void
    
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    @EnvironmentObject var appMode: AppModeManager
    
    @Binding var nodeFrames: [UUID: CGRect]
    @Binding var viewportHeight: CGFloat
    @Binding var isEditMode: Bool
    @Binding var showJumpButton: Bool
    @Binding var scrollToNowTrigger: Int
    
    // Auto-Scroll State
    @State private var autoScrollTimer: Timer?
    @State private var autoScrollDirection: AutoScrollDirection?
    
    // Auto-Restore Scroll State
    @State private var restoreScrollTrigger: Int = 0
    @State private var isUserScrolling: Bool = false
    @State private var scrollViewFrame: CGRect = .zero
    @State private var manualScrollResumeAt: TimeInterval = 0
    @State private var reanchorWorkItem: DispatchWorkItem?

    var body: some View {
        ScrollViewReader { proxy in
            timelineContainer(proxy: proxy)
        }
    }
    
    // MARK: - Helpers
    
    private func isDeadZone(_ dest: Int?, _ draggedId: UUID?) -> Bool {
        guard let id = draggedId,
              let cur = daySession.nodes.firstIndex(where: { $0.id == id }) else { return false }
        return dest == cur || dest == cur + 1
    }
    
    private func handleDragLocationChange(_ newLocation: CGPoint, proxy: ScrollViewProxy) {
        // 1. Update Sorting / Hover Logic
        let isDragging = dragCoordinator.isDragging
        
        if isDragging {
            // Filter out completed tasks from allowed drop targets
            let pendingNodes = daySession.nodes.filter { !$0.isCompleted }.map { $0.id }
            let allowed = Set(pendingNodes)
            let currentFrames = self.nodeFrames
            let topDropThreshold = (scrollViewFrame == .zero)
                ? AutoScrollConfig.topDropZoneTrigger
                : scrollViewFrame.minY + AutoScrollConfig.topDropZoneTrigger

            if newLocation.y < topDropThreshold {
                if let lastAllowedId = daySession.nodes.last(where: { allowed.contains($0.id) })?.id {
                    dragCoordinator.hoveringNodeId = lastAllowedId
                    dragCoordinator.hoveringPlacement = .after
                } else {
                    dragCoordinator.hoveringNodeId = nil
                    dragCoordinator.hoveringPlacement = .after
                }
            } else {
                DispatchQueue.main.async { [weak dragCoordinator] in
                     dragCoordinator?.updatePosition(newLocation, nodeFrames: currentFrames, allowedNodeIds: allowed)
                }
            }
        }
        
        // 2. Auto-Scroll Logic
        guard dragCoordinator.isDragging else {
            stopAutoScroll()
            return
        }
        
        let topTrigger = (scrollViewFrame == .zero)
            ? AutoScrollConfig.edgeZoneTop
            : scrollViewFrame.minY + AutoScrollConfig.edgeZoneTop
        let bottomTrigger = (scrollViewFrame == .zero)
            ? (viewportHeight - AutoScrollConfig.edgeZoneBottom)
            : (scrollViewFrame.maxY - AutoScrollConfig.edgeZoneBottom)

        if newLocation.y < topTrigger {
            startAutoScroll(direction: .towardsEnd, proxy: proxy) 
        } else if newLocation.y > bottomTrigger {
            startAutoScroll(direction: .towardsStart, proxy: proxy)
        } else {
            stopAutoScroll()
        }
    }
    
    private func startAutoScroll(direction: AutoScrollDirection, proxy: ScrollViewProxy) {
        if let current = autoScrollTimer, autoScrollDirection == direction, current.isValid {
            return
        }
        
        stopAutoScroll()
        autoScrollDirection = direction
        
        let interval = AutoScrollConfig.interval
        let animationDuration = AutoScrollConfig.animationDuration
        let isTowardsEnd = direction == .towardsEnd
        let step = direction.step
        let scrollAnchor: UnitPoint = isTowardsEnd ? .top : .bottom
        
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            let visibleNode: (key: UUID, value: CGRect)?
            if isTowardsEnd {
                // Direction +1 (Towards End/Index N) -> Scroll to Min Y (Top of Screen in Inverted View?)
                // Inverted: Index N is visible at Top.
                visibleNode = nodeFrames.min { $0.value.minY < $1.value.minY }
            } else {
                // Direction -1 (Towards Start/Index 0) -> Scroll to Max Y (Bottom of Screen?)
                visibleNode = nodeFrames.max { $0.value.maxY < $1.value.maxY }
            }
            
            guard let anchorId = visibleNode?.key,
                  let currentIndex = daySession.nodes.firstIndex(where: { $0.id == anchorId }) else { return }
            
            let nextIndex = currentIndex + step
            
            if nextIndex >= 0 && nextIndex < daySession.nodes.count {
                let targetId = daySession.nodes[nextIndex].id
                withAnimation(.easeOut(duration: animationDuration)) {
                    proxy.scrollTo(targetId, anchor: scrollAnchor)
                }
            }
        }
    }
    
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        autoScrollDirection = nil
    }
    
    private func startRestoreTimer(proxy: ScrollViewProxy) {
        restoreScrollTrigger += 1
    }
    
    private func stopRestoreTimer() {
        restoreScrollTrigger = 0
    }

    private func requestReanchor(using proxy: ScrollViewProxy, delay: TimeInterval) {
        guard !isUserScrolling,
              !dragCoordinator.isDragging,
              !appMode.isDragging,
              !isEditMode else { return }
        if Date().timeIntervalSinceReferenceDate < manualScrollResumeAt {
            return
        }
        reanchorWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak dragCoordinator] in
            guard dragCoordinator?.isDragging == false else { return }
            scrollToActive(using: proxy)
        }
        reanchorWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    private func scrollToActive(using proxy: ScrollViewProxy, explicitAnchor: UnitPoint? = nil) {
        let targetId = viewModel.isSessionActive ? daySession.currentNode?.id : viewModel.upcomingNodes.first?.id
        guard let targetId else { return }
        let anchorY = 1.0 - AnchorConfig.fixedTopTargetRatio
        let anchor = explicitAnchor ?? UnitPoint(x: 0.5, y: anchorY)
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            proxy.scrollTo(targetId, anchor: anchor)
        }
    }
    
    private func shouldShowJumpButtonInternal() -> Bool {
        guard !appMode.isDragging, !dragCoordinator.isDragging else { return false }
        guard manualScrollResumeAt > Date().timeIntervalSinceReferenceDate else { return false }
        let targetId = viewModel.isSessionActive ? daySession.currentNode?.id : viewModel.upcomingNodes.first?.id
        guard let targetId, let frame = nodeFrames[targetId], scrollViewFrame != .zero else { return false }
        let anchorY = scrollViewFrame.minY + (scrollViewFrame.height * (1.0 - AnchorConfig.fixedTopTargetRatio))
        return abs(frame.midY - anchorY) > AnchorConfig.jumpButtonDistanceThreshold
    }
    
    private func updateJumpButtonVisibility() {
        let shouldShow = shouldShowJumpButtonInternal()
        if showJumpButton != shouldShow {
            showJumpButton = shouldShow
        }
    }
}

// MARK: - Auto Scroll Helpers

private enum AutoScrollDirection {
    case towardsEnd
    case towardsStart
    
    var step: Int {
        switch self {
        case .towardsEnd: return 1
        case .towardsStart: return -1
        }
    }
}

private enum AutoScrollConfig {
    static let edgeZoneTop: CGFloat = 12
    static let edgeZoneBottom: CGFloat = 90
    static let interval: TimeInterval = 0.44
    static let animationDuration: TimeInterval = 0.36
    static let topDropZoneTrigger: CGFloat = 28
}

private enum AnchorConfig {
    // Anchor current task to a fixed percentage of the visible viewport height.
    // Inverted scroll view: scrollToActive flips the ratio to keep it intuitive.
    static let fixedTopTargetRatio: CGFloat = MapViewModel.anchorRatio
    static let restoreDelay: TimeInterval = 20
    static let jumpButtonDistanceThreshold: CGFloat = 120
}

extension TimelineListView {
    @ViewBuilder
    private func timelineContainer(proxy: ScrollViewProxy) -> some View {
        timelineContent(proxy: proxy)
            .onChange(of: appMode.isDragging) { _, isDragging in
                if !isDragging {
                    stopAutoScroll()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: daySession.nodes.count)
            .onPreferenceChange(NodeFrameKey.self) { frames in
                // Fix for "Publishing changes from within view updates" loop
                DispatchQueue.main.async {
                    nodeFrames = frames
                    updateJumpButtonVisibility()
                }
            }
            .onChange(of: dragCoordinator.dragLocation) { _, newLocation in
                // Defer complex layout logic to next run loop to avoid gesture conflicts and layout loops
                DispatchQueue.main.async {
                    handleDragLocationChange(newLocation, proxy: proxy)
                }
            }
            .onChange(of: dragCoordinator.isDragging) { _, isDragging in
                if isDragging {
                    stopRestoreTimer()
                    // Snap to start position when dragging a task out
                    // Defer to avoid "Publishing changes from within view updates"
                    DispatchQueue.main.async {
                        // Snap to active position logic removed to prevent gesture cancellation
                        // Scroll restoration after drag is handled by appMode listener or manual scroll
                        // scrollToActive(using: proxy)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { _ in
                        isUserScrolling = true
                        manualScrollResumeAt = Date().timeIntervalSinceReferenceDate + AnchorConfig.restoreDelay
                        stopRestoreTimer()
                        updateJumpButtonVisibility()
                    }
                    .onEnded { _ in
                        isUserScrolling = false
                        manualScrollResumeAt = Date().timeIntervalSinceReferenceDate + AnchorConfig.restoreDelay
                        startRestoreTimer(proxy: proxy)
                    }
            )
            .onDisappear {
                stopAutoScroll()
                stopRestoreTimer()
            }
            .onChange(of: daySession.nodes.count) { _, newCount in
                if let currentId = daySession.currentNode?.id, let _ = nodeFrames[currentId] {
                    // print("📍 [Timeline Debug] Count Changed (\(newCount)). Current Node Frame: \(frame)")
                }
                requestReanchor(using: proxy, delay: 0.35)
            }
            .onChange(of: daySession.currentIndex) { _, _ in
                // Re-anchor after the current card size transition settles.
                requestReanchor(using: proxy, delay: 0.35)
            }
            .task(id: restoreScrollTrigger) {
                guard restoreScrollTrigger > 0 else { return }
                do {
                    try await Task.sleep(nanoseconds: 20_000_000_000) // 20s
                    guard !isUserScrolling,
                          !dragCoordinator.isDragging,
                          !appMode.isDragging else { return }
                    withAnimation(.easeOut(duration: 0.5)) {
                        requestReanchor(using: proxy, delay: 0)
                    }
                } catch {}
            }
            .onAppear {
                // Ensure we scroll to active when view appears (e.g. returning from Focus)
                requestReanchor(using: proxy, delay: 0.05)
            }
            .onChange(of: scrollToNowTrigger) { _, _ in
                scrollToActive(using: proxy)
            }
            .onChange(of: manualScrollResumeAt) { _, _ in
                updateJumpButtonVisibility()
            }
    }

    @ViewBuilder
    private func nodeRow(index: Int, node: TimelineNode, dropIndex: Int?) -> some View {
        VStack(spacing: 0) {
            // Drop Zone logic:
            // Show if this is the target drop index AND it's not a "dead zone" (same position)
            DragTargetRow(isActive: (dropIndex == index) && !isDeadZone(index, dragCoordinator.draggedNodeId))
            
            TimelineNodeRow(
                node: node,
                index: index,
                isSelected: false,
                isCurrent: viewModel.shouldShowAsCurrentTask(node: node),
                isEditMode: isEditMode,
                onTap: { onAction(.tap(node)) },
                onEdit: { onAction(.edit(node)) },
                onDuplicate: { onAction(.duplicate(node)) },
                onDelete: { onAction(.delete(node)) },
                onMoveUp: { onAction(.moveUp(node)) },
                onMoveDown: { onAction(.moveDown(node)) },
                onDrop: { _ in },
                totalNodesCount: daySession.nodes.count,
                contentOffset: 0,
                estimatedTimeLabel: viewModel.estimatedStartTime(for: node, upcomingNodes: viewModel.upcomingNodes)?.absolute
            )
            // Flip each row back to upright
            .scaleEffect(x: 1, y: -1)
            // Disable animation during drag to preventing view sliding away from finger
            .animation(nil, value: dragCoordinator.hoveringNodeId)
            // ✅ Layout Shift Compensation:
            .offset(y: {
                guard dragCoordinator.draggedNodeId == node.id,
                      let dropIndex,
                      dropIndex <= index,
                      !isDeadZone(dropIndex, dragCoordinator.draggedNodeId)
                else { return 0 }
                return -92
            }())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .id(node.id)
            // Disable interaction with other rows during drag to prevent gesture stealing
            .allowsHitTesting(!dragCoordinator.isDragging || dragCoordinator.draggedNodeId == node.id)
        }
    }
    
    @ViewBuilder
    private func timelineContent(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            // Inverted Timeline: Stack 0..N, then flio Y axis
            LazyVStack(spacing: 0) {
                // PADDING SHIM:
                // In inverted view, this "Top" item sits at the Visual Bottom.
                // We want the first real item (Index 0) to sit at mapAnchorY (e.g. 0.7).
                // So we need padding of (1.0 - 0.7 = 0.3) height.
                let anchorY = viewModel.mapAnchorY(viewportHeight: viewportHeight)
                let paddingHeight = max(0, viewportHeight * (1.0 - anchorY))
                
                Color.clear
                    .frame(height: paddingHeight)
                    .scaleEffect(x: 1, y: -1) // Flip it back so it takes space normally?
                
                let dropIndex = dragCoordinator.isDragging ? dragCoordinator.destinationIndex(in: daySession.nodes) : nil
                
                ForEach(Array(daySession.nodes.enumerated()), id: \.element.id) { index, node in
                    nodeRow(index: index, node: node, dropIndex: dropIndex)
                }
                
                // Final Drop Zone (Append to end)
                DragTargetRow(isActive: (dropIndex == daySession.nodes.count) && !isDeadZone(daySession.nodes.count, dragCoordinator.draggedNodeId))
                    .scaleEffect(x: 1, y: -1) // Flip this too? Yes.
            }
            .frame(maxWidth: .infinity)
        }
        .scaleEffect(x: 1, y: -1) // Flip the ScrollView (Key Fix: Anchor moves to Bottom)
        .background(timelineBackground)
        .scrollDisabled(appMode.isDragging)
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var timelineBackground: some View {
        ZStack {
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        scrollViewFrame = geo.frame(in: .global)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        scrollViewFrame = newFrame
                        updateJumpButtonVisibility()
                    }
            }
        }
    }
}
