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
    @State private var wasInDeadZoneForHaptic = true
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Ghost at Top
                    if dragCoordinator.isDragging,
                       dragCoordinator.destinationIndex(in: daySession.nodes) == daySession.nodes.count,
                       !isDeadZone(dragCoordinator.destinationIndex(in: daySession.nodes), dragCoordinator.draggedNodeId) {
                        GhostNodeView()
                            .transition(.opacity)
                            .padding(.vertical, 6)
                    }

                    ForEach(daySession.nodes.reversed()) { node in
                        let index = daySession.nodes.firstIndex(where: { $0.id == node.id }) ?? 0
                        
                        TimelineNodeRow(
                            node: node,
                            index: index,
                            isSelected: false,
                            isCurrent: viewModel.shouldShowAsCurrentTask(node: node),
                            isEditMode: false, // Passed down from parent if needed, but for now we rely on buttons
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
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragCoordinator.hoveringNodeId)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragCoordinator.hoveringPlacement)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .id(node.id)
                        
                        // Ghost In-Between
                        if dragCoordinator.isDragging,
                           dragCoordinator.destinationIndex(in: daySession.nodes) == index,
                           !isDeadZone(index, dragCoordinator.draggedNodeId) {
                            GhostNodeView()
                                .transition(.opacity)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .scrollDisabled(appMode.isDragging)
            .contentShape(Rectangle())
            .onChange(of: appMode.isDragging) { _, isDragging in
                if !isDragging {
                    stopAutoScroll()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: daySession.nodes.count)
            .animation(.easeInOut(duration: 0.25), value: daySession.nodes.map(\.id))
            .onPreferenceChange(NodeFrameKey.self) { frames in
                nodeFrames = frames
            }
            .onChange(of: dragCoordinator.dragLocation) { _, newLocation in
                handleDragLocationChange(newLocation, proxy: proxy)
            }
            .onChange(of: dragCoordinator.draggedNodeId) { _, newId in
                if newId != nil { wasInDeadZoneForHaptic = true }
            }
            .onChange(of: daySession.nodes.count) { _, _ in
                scrollToActive(using: proxy)
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
        // Haptics logic
        if let _ = dragCoordinator.draggedNodeId {
            let dest = dragCoordinator.destinationIndex(in: daySession.nodes)
            let dead = isDeadZone(dest, dragCoordinator.draggedNodeId)
            if dead {
                wasInDeadZoneForHaptic = true
            } else {
                if wasInDeadZoneForHaptic {
                    Haptics.selection()
                    wasInDeadZoneForHaptic = false
                }
            }
        }
        
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
                visibleNode = nodeFrames.min { $0.value.minY < $1.value.minY }
            } else {
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
    
    private func scrollToActive(using proxy: ScrollViewProxy) {
        let targetId = viewModel.isSessionActive ? daySession.currentNode?.id : viewModel.upcomingNodes.first?.id
        guard let targetId else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.35)) {
                
                proxy.scrollTo(targetId, anchor: UnitPoint(x: 0.5, y: viewModel.mapAnchorY(viewportHeight: viewportHeight)))
            }
        }
    }
}

// Minimal placeholder if GhostNodeView isn't global
struct GhostNodeView_Placeholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.1))
            .frame(height: 60)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundColor(Color.gray.opacity(0.3))
            )
    }
}
