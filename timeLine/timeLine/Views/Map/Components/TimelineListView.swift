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
    
    // Auto-Scroll State
    @State private var autoScrollTimer: Timer?
    @State private var autoScrollDirection: Int = 0 
    // Stable Anchoring State
    @State private var lastActiveNodeId: UUID?

    var body: some View {
        ScrollViewReader { proxy in
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
                        // Actually, plain frame takes space regardless of scale.
                        // But if we want to be safe...
                    let dropIndex = dragCoordinator.isDragging ? dragCoordinator.destinationIndex(in: daySession.nodes) : nil
                    let draggedIndex = daySession.nodes.firstIndex(where: { $0.id == dragCoordinator.draggedNodeId })
                    
                    ForEach(Array(daySession.nodes.enumerated()), id: \.element.id) { index, node in
                        VStack(spacing: 0) {
                            // Drop Zone logic:
                            // Show if this is the target drop index AND it's not a "dead zone" (same position)
                            let isDeadZone = (index == draggedIndex) || (index == (draggedIndex ?? -1) + 1)
                            DragTargetRow(isActive: (dropIndex == index) && !isDeadZone)
                            
                            TimelineNodeRow(
                                node: node,
                                index: index,
                                isSelected: false,
                                isCurrent: viewModel.shouldShowAsCurrentTask(node: node),
                                isEditMode: false,
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
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragCoordinator.hoveringNodeId)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .id(node.id)
                        }
                    }
                    
                    // Final Drop Zone (Append to end)
                    // Check dead zone for end (draggedIndex == count - 1 => next is count. count is dead zone?)
                    // If dragged node is last (index N-1), dropping at N is Dead Zone.
                    let isEndDeadZone = (daySession.nodes.count == (draggedIndex ?? -1) + 1)
                    DragTargetRow(isActive: (dropIndex == daySession.nodes.count) && !isEndDeadZone)
                        .scaleEffect(x: 1, y: -1) // Flip this too? Yes.
                }
                .frame(maxWidth: .infinity)
            }
            .scaleEffect(x: 1, y: -1) // Flip the ScrollView (Key Fix: Anchor moves to Bottom)
            .scrollDisabled(appMode.isDragging)
            .contentShape(Rectangle())
            .onChange(of: appMode.isDragging) { _, isDragging in
                if !isDragging {
                    stopAutoScroll()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: daySession.nodes.count)
            .onPreferenceChange(NodeFrameKey.self) { frames in
                nodeFrames = frames
            }
            .onChange(of: dragCoordinator.dragLocation) { _, newLocation in
                handleDragLocationChange(newLocation, proxy: proxy)
            }
            .onChange(of: daySession.nodes.count) { _, newCount in
                // With inverted scroll, inserting at Index 0 (Visual Bottom/Physical Top)
                // naturally pushes existing content "Down" (Physically) -> "Up" (Visually).
                
                if let currentId = daySession.currentNode?.id, let frame = nodeFrames[currentId] {
                    print("📍 [Timeline Debug] Count Changed (\(newCount)). Current Node Frame: \(frame)")
                    print("   - Visual Pos: minY = \(Int(frame.minY)), midY = \(Int(frame.midY))")
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    scrollToActive(using: proxy)
                }
            }
            .onChange(of: daySession.currentIndex) { _, _ in
                scrollToActive(using: proxy)
            }
            .onAppear {
                scrollToActive(using: proxy)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func isDeadZone(_ dest: Int?, _ draggedId: UUID?) -> Bool {
        guard let id = draggedId,
              let cur = daySession.nodes.firstIndex(where: { $0.id == id }) else { return false }
        return dest == cur || dest == cur + 1
    }
    
    private func handleDragLocationChange(_ newLocation: CGPoint, proxy: ScrollViewProxy) {
        // Haptics logic - Disabled for now as requested
        
        // Auto-Scroll Logic
        guard dragCoordinator.isDragging else {
            stopAutoScroll()
            return
        }
        
        let threshold: CGFloat = 120
        if newLocation.y < threshold {
            startAutoScroll(direction: 1, proxy: proxy) 
        } else if newLocation.y > (viewportHeight - threshold) {
            startAutoScroll(direction: -1, proxy: proxy)
        } else {
            stopAutoScroll()
        }
    }
    
    private func startAutoScroll(direction: Int, proxy: ScrollViewProxy) {
        if let current = autoScrollTimer, autoScrollDirection == direction, current.isValid {
            return
        }
        
        stopAutoScroll()
        autoScrollDirection = direction
        
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let visibleNode: (key: UUID, value: CGRect)?
            if direction > 0 {
                // Direction +1 (Towards End/Index N) -> Scroll to Min Y (Top of Screen in Inverted View?)
                // Inverted: Index N is visible at Top.
                visibleNode = nodeFrames.min { $0.value.minY < $1.value.minY }
            } else {
                // Direction -1 (Towards Start/Index 0) -> Scroll to Max Y (Bottom of Screen?)
                visibleNode = nodeFrames.max { $0.value.maxY < $1.value.maxY }
            }
            
            guard let anchorId = visibleNode?.key,
                  let currentIndex = daySession.nodes.firstIndex(where: { $0.id == anchorId }) else { return }
            
            let nextIndex = currentIndex + direction
            
            if nextIndex >= 0 && nextIndex < daySession.nodes.count {
                let targetId = daySession.nodes[nextIndex].id
                withAnimation(.linear(duration: 0.1)) {
                    proxy.scrollTo(targetId, anchor: direction > 0 ? .top : .bottom)
                }
            }
        }
    }
    
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        autoScrollDirection = 0
    }
    
    private func scrollToActive(using proxy: ScrollViewProxy, explicitAnchor: UnitPoint? = nil) {
        let targetId = viewModel.isSessionActive ? daySession.currentNode?.id : viewModel.upcomingNodes.first?.id
        guard let targetId else { return }
        
        if let frame = nodeFrames[targetId] {
            print("⚓️ [Timeline Debug] Scrolling to Target \(targetId)")
            print("   - Current Frame: \(frame)")
        }

        let anchor: UnitPoint
        if let explicit = explicitAnchor {
            anchor = explicit
            print("⚓️ [Timeline] Scrolling to Explicit Anchor: \(String(format: "%.2f", explicit.y))")
        } else {
            // Default behavior
            // Inverted: Visual Bottom (Standard 0.7) is Physical Top (0.3).
            // Let's try .center (0.5) first as it is invariant.
            anchor = .center
        }

        withAnimation(.easeOut(duration: 0.2)) {
          proxy.scrollTo(targetId, anchor: anchor)
        }
    }
}
