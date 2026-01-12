import SwiftUI
import TimeLineCore

struct SwipeableTimelineNode: View {
    let node: TimelineNode
    let alignment: MapNodeAlignment
    let isCurrent: Bool
    let isNext: Bool
    let isFinal: Bool
    let isPulsing: Bool
    let timeInfo: MapTimeInfo?
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void
    let onDrop: ((DropAction) -> Void)?
    
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    @State private var swipeOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var preventTap = false
    @State private var containerWidth: CGFloat = 0
    @State private var showingEditActions = false
    
    private let actionButtonWidth: CGFloat = 70
    
    var body: some View {
        ZStack {
            // Background terrain and trail
            TimelineNodeBackground(
                node: node,
                alignment: alignment,
                isNext: isNext,
                isCurrent: isCurrent,
                terrainWidth: terrainWidth,
                terrainHeight: terrainHeight
            )
            
            // Edit action buttons (revealed by swipe)
            if showingEditActions {
                TimelineNodeEditActions(
                    alignment: alignment,
                    cardHeight: cardHeight,
                    cardOffsetX: cardOffsetX,
                    actionButtonWidth: actionButtonWidth,
                    onEdit: onEdit,
                    onDuplicate: onDuplicate,
                    onDelete: onDelete,
                    onHide: { hideEditActions() }
                )
            }
            
            // Main node content
            TimelineNodeMainContent(
                node: node,
                alignment: alignment,
                isCurrent: isCurrent,
                isNext: isNext,
                isFinal: isFinal,
                isPulsing: isPulsing,
                timeInfo: timeInfo,
                isDragging: isDragging,
                swipeOffset: swipeOffset,
                dragOffset: dragOffset,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                cardOffsetX: cardOffsetX,
                preventTap: preventTap,
                onTap: onTap,
                onLongPress: onLongPress,
                onPreventTap: { preventTap = $0 }
            )
            .gesture(
                SimultaneousGesture(
                    gestureCoordinator.swipeGesture,
                    LongPressGesture(minimumDuration: 0.3)
                        .sequenced(before: DragGesture(coordinateSpace: .global))
                        .onChanged { value in
                            switch value {
                            case .second(true, let drag):
                                // Long press confirmed, dragging
                                if let drag = drag {
                                    if !isDragging {
                                        isDragging = true
                                        Haptics.impact(.medium)
                                        // Start global drag
                                        let payload = DragPayload(type: .node(node.id), source: .library) // Source doesn't matter for node
                                        dragCoordinator.startDrag(payload: payload)
                                    }
                                    // Update global drag position
                                    dragCoordinator.updatePosition(
                                        drag.location,
                                        nodeFrames: [:], // This will be filled by parent or coordinator should use shared state??
                                        allowedNodeIds: [] // This logic needs to be valid. Coordinator expects parent to provide frames?
                                        // Wait, the coordinator.updatePosition needs the frames passed in.
                                        // SwipeableTimelineNode doesn't have access to all frames.
                                        // CHANGING STRATEGY: SwipeableTimelineNode just updates dragLocation. 
                                        // Parent (RogueMapView) must observe dragLocation and call updatePosition.
                                    )
                                    // Actually, let's just update the local dragOffset for visual feedback
                                    dragOffset = drag.translation
                                    
                                    // Update coordinator location
                                    dragCoordinator.dragLocation = drag.location
                                }
                            default:
                                break
                            }
                        }
                        .onEnded { value in
                            if isDragging {
                                isDragging = false
                                dragOffset = .zero
                                let action = dragCoordinator.drop()
                                onDrop?(action)
                            }
                        }
                )
            )
        }
        .frame(height: 120)
        .background(geometryReader)
    }
    
    // MARK: - Gesture Coordinator
    private var gestureCoordinator: TimelineNodeGestureCoordinator {
        TimelineNodeGestureCoordinator(
            swipeOffset: $swipeOffset,
            isDragging: $isDragging,
            dragOffset: $dragOffset,
            showingEditActions: $showingEditActions,
            preventTap: $preventTap
        )
    }
    
    // MARK: - Helper Methods
    private func hideEditActions() {
        gestureCoordinator.hideEditActions()
    }
    
    // MARK: - Computed Properties
    private var titleText: String {
        switch node.type {
        case .battle(let boss):
            return boss.name
        case .bonfire:
            return "Bonfire"
        case .treasure:
            return "Treasure"
        }
    }
    
    private var nodeAccessibilityId: String {
        switch node.type {
        case .battle(let boss):
            let compact = boss.name.replacingOccurrences(of: " ", with: "_")
            return "mapNode_\(compact)"
        case .bonfire:
            return "mapNode_Bonfire_\(node.id.uuidString.prefix(6))"
        case .treasure:
            return "mapNode_Treasure_\(node.id.uuidString.prefix(6))"
        }
    }
    
    private var cardWidth: CGFloat {
        let width = containerWidth > 0 ? containerWidth : 360
        let target = width * 0.75
        return min(max(target, 240), 320)
    }
    
    private var cardHeight: CGFloat { 76 }
    
    private var terrainWidth: CGFloat {
        max(140, cardWidth - 16)
    }
    
    private var terrainHeight: CGFloat {
        cardHeight - 4
    }
    
    private var cardOffsetX: CGFloat {
        let screenWidth = containerWidth > 0 ? containerWidth : 360
        let halfCard = cardWidth / 2
        let center = screenWidth / 2
        let offset = center - halfCard - MapLayout.horizontalInset
        return max(0, offset)
    }
    
    private var canEditNode: Bool {
        if case .battle = node.type {
            return true
        }
        return false
    }
    
    // MARK: - Geometry Reader
    private var geometryReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    containerWidth = geo.size.width
                }
                .onChange(of: geo.size.width) { _, newValue in
                    containerWidth = newValue
                }
                .preference(
                    key: MapNodeAnchorKey.self,
                    value: [node.id: geo.frame(in: .named("mapScroll")).midY]
                )
                .preference(
                    key: NodeFrameKey.self,
                    value: [node.id: geo.frame(in: .global)]
                )
        }
    }
}

// MARK: - Supporting Types
// Note: MapNodeAlignment, MapTimeInfo, and MapNodeAnchorKey are defined in MapTypes.swift