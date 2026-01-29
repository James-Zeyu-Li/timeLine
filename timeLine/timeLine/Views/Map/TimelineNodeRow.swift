import SwiftUI
import TimeLineCore

struct TimelineNodeRow: View {
    let node: TimelineNode
    let index: Int
    let isSelected: Bool
    let isCurrent: Bool
    let isEditMode: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDrop: (DropAction) -> Void
    let totalNodesCount: Int
    
    // New property for layout offset (from reordering)
    var contentOffset: CGFloat = 0
    
    // Estimated start time label (e.g., "7:30 PM")
    var estimatedTimeLabel: String? = nil
    
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var daySession: DaySession
    
    @State private var isPressing = false
    @State private var nodeFrame: CGRect = .zero
    @State private var menuButtonFrame: CGRect = .zero
    @Namespace private var ns // For floating button
    
    // MARK: - Presenter
    private var presenter: TimelineNodePresenter {
        TimelineNodePresenter(
            node: node,
            isCurrent: isCurrent,
            engine: engine,
            daySession: daySession
        )
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // MARK: - Interactive Card Container
            HStack(alignment: .top, spacing: 0) {
                // 1. Left Axis
                ZStack {
                    // Timeline Line
                    TimelinePathLine(isCompleted: node.isCompleted, isCurrent: isCurrent)
                        .frame(width: 40)
                        .frame(maxHeight: .infinity)
                    
                    VStack(spacing: 4) {
                        // Node Icon
                        TimelineNodeIconView(
                            iconName: presenter.iconName,
                            iconSize: presenter.iconSize,
                            iconImageSize: presenter.iconImageSize,
                            backgroundColor: presenter.iconBackgroundColor,
                            foregroundColor: presenter.iconForegroundColor
                        )
                        
                        // Time Marker
                        TimelineTimeMarker(
                            isCurrent: isCurrent,
                            estimatedTimeInfo: estimatedTimeLabel,
                            isCompleted: node.isCompleted
                        )
                    }
                    .padding(.top, isCurrent ? 24 : 12)
                }
                .frame(width: 50)
                
                // 2. Card Content
                if isCurrent {
                    TimelineActiveCard(
                        presenter: presenter,
                        onTap: onTap,
                        onEdit: onEdit,
                        onMenuFrameChange: { frame in
                            menuButtonFrame = frame.insetBy(dx: -6, dy: -6)
                        },
                        namespace: ns,
                        nodeId: node.id
                    )
                } else {
                    TimelineCompactCard(
                        presenter: presenter,
                        node: node
                    )
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onEnded { value in
                        guard !appMode.isDragging else { return }
                        let isTap = abs(value.translation.width) < 10 && abs(value.translation.height) < 10
                        guard isTap else { return }
                        if isCurrent, menuButtonFrame != .zero {
                            let hitBox = menuButtonFrame.insetBy(dx: -12, dy: -12)
                            if hitBox.contains(value.location) { return }
                        }
                        onTap()
                    }
            )
            .scaleEffect(isPressing ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressing)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragCoordinator.hoveringNodeId)
            // 关键修改：使用 overlay 而不是 background
            // 并且用 GeometryReader 确保填充整个区域
            .overlay(
                GeometryReader { geo in
                    if !appMode.isDragging || dragCoordinator.draggedNodeId == node.id {
                        LongPressDraggable(
                            minimumDuration: 0.4,
                            movementThreshold: 10,
                            exclusionRect: (isCurrent && menuButtonFrame != .zero) ? menuButtonFrame : nil,
                            onLongPress: { state, location in
                                // print("🛠 [UIKit] Overlay LongPress: \(state.rawValue)")
                                handleLongPress(state: state, location: location)
                            },
                            onPressing: { pressing in
                                if !appMode.isDragging {
                                    isPressing = pressing
                                }
                            }
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                GeometryReader { geo in
                    if isCurrent, menuButtonFrame != .zero {
                        let localFrame = CGRect(
                            x: menuButtonFrame.minX - geo.frame(in: .global).minX,
                            y: menuButtonFrame.minY - geo.frame(in: .global).minY,
                            width: menuButtonFrame.width,
                            height: menuButtonFrame.height
                        )
                        Button(action: onEdit) {
                            Color.clear
                        }
                        .frame(width: localFrame.width, height: localFrame.height)
                        .position(x: localFrame.midX, y: localFrame.midY)
                        .contentShape(Rectangle())
                    }
                }
            )
            // 3. Floating Play Button (Z-Index Fix)
            // Sits ON TOP of the LongPressDraggable overlay
            .overlay(
                Group {
                    if isCurrent {
                        ZStack {
                            Circle()
                                .fill(PixelTheme.primary)
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: 2)
                        }
                        .contentShape(Circle())
                        .matchedGeometryEffect(id: "playButton-\(node.id)", in: ns, isSource: false)
                        .onTapGesture {
                            Haptics.impact(.medium)
                            onTap()
                        }
                    }
                }
            )
            
            // 3. Edit Buttons (Sibling, not inside main button)
            if isEditMode {
                editModeButtons
            }
        }
        .background(frameReporter)
        .opacity(dragCoordinator.draggedNodeId == node.id ? 0 : 1)
        .animation(nil, value: dragCoordinator.draggedNodeId == node.id) // Force NO animation for opacity
        .animation(.spring(response: 0.32, dampingFraction: 0.92), value: isCurrent)
        // Remove redundant outer animation that might conflict or use default params if not careful.
        // The ListView handles the list reordering animation. Here we just handle internal state.
    }
    
    // MARK: - Frame Reporter
    
    private var frameReporter: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: NodeFrameKey.self,
                    value: [node.id: geo.frame(in: .global)]
                )
                .onAppear { 
                    self.nodeFrame = geo.frame(in: .global) 
                }
                // .onChange removed to prevent update loops. 
                // Note: local nodeFrame might be stale on scroll, but PreferenceKey is fresh.
        }
    }
    
    // MARK: - Edit Mode Buttons
    
    private var editModeButtons: some View {
        HStack(spacing: 8) {
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 12)
        .padding(.top, isCurrent ? 20 : 12)
    }
    
    // MARK: - Gestures
    
    private func handleLongPress(state: UIGestureRecognizer.State, location: CGPoint) {
        print("📍 [Gesture] Node: \(node.id), Index: \(index), isCurrent: \(isCurrent)")
        print("   State: \(state.rawValue), Y: \(location.y), isDragging: \(appMode.isDragging)")
        switch state {
        case .began:
            // Long Press Succeeded (0.4s elapsed)
            // Start Drag
            if !appMode.isDragging {
                print("🚀 [UIKit] LongPress Began at Y: \(location.y). Starting Drag...")
                Haptics.impact(.medium)
                isPressing = false
                
                let center = CGPoint(x: nodeFrame.midX, y: nodeFrame.midY)
                let start = location
                let offset = CGSize(width: center.x - start.x, height: center.y - start.y)
                
                let payload: DragPayload
                if node.isCompleted {
                    payload = DragPayload(type: .nodeCopy(node.id), source: .library, initialOffset: offset)
                } else {
                    payload = DragPayload(type: .node(node.id), source: .library, initialOffset: offset)
                }
                
                // Defer state update to avoid publishing during view update
                Task { @MainActor in
                    dragCoordinator.startDrag(payload: payload)
                    appMode.enter(.dragging(payload))
                    if appMode.isDragging {
                        dragCoordinator.dragLocation = location
                    } else {
                        dragCoordinator.reset()
                    }
                }
            }
            
        case .changed:
            if appMode.isDragging {
                // GlobalDragTracker will drive movement once active; avoid double-updates.
                if dragCoordinator.initialDragLocation == nil {
                    Task { @MainActor in
                        dragCoordinator.dragLocation = location
                    }
                }
            }
            
        case .ended:
            if appMode.isDragging {
                print("🛑 [UIKit] Drag Ended.")
                Task { @MainActor in
                    dragCoordinator.isDragEnded = true
                }
            }
            isPressing = false
        case .cancelled, .failed:
            // Ignore cancellation: the global tracker will finish the drag on touch end.
            isPressing = false
            
        default:
            break
        }
    }
}

// MARK: - Helper Style
// CardButtonStyle is already defined in Shared/ButtonStyles.swift
