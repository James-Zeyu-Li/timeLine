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
            // [最终架构方案]
            // 分离视觉与逻辑，移除 Button 以避免冲突
            // 1. onTapGesture -> 点击
            // 2. Visual Gesture -> 按下视觉反馈 (Drag min 0)
            // 3. Logic Gesture -> 长按拖拽 (LongPress 0.4s -> Drag)
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
                        onEdit: onEdit
                    )
                } else {
                    TimelineCompactCard(
                        presenter: presenter,
                        node: node
                    )
                }
            }
            .onTapGesture {
                onTap()
            }
            .scaleEffect(isPressing ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressing)
            // 统一手势：使用 UIKit 穿透方案解决 ScrollView 冲突 (改回 overlay 确保能收到触摸)
            .overlay(
                LongPressDraggable(
                    minimumDuration: 0.4,
                    movementThreshold: 10,
                    onLongPress: { state, location in
                        print("🛠 [UIKit Wrapper] LongPress Callback: \(state.rawValue)")
                        handleLongPress(state: state, location: location)
                    },
                    onPressing: { pressing in
                        if !appMode.isDragging {
                            isPressing = pressing
                        }
                    }
                )
            )
            // Tap 单独处理，UIKit 层设为 non-cancelling，所以点击应该能穿透到这里？
            // 或者我们可以让 LongPressDraggable 也处理点击？
            // 简单起见，保持 SwiftUI 点击。由于 allowsHitTesting(false) 会导致点击失效，
            // 我们的 overlay 是透明的 UIView，默认吃点击吗？
            // UIView(frame: .zero) 默认 userInteractionEnabled = true。
            // 但如果它由于 frame 覆盖了 content，SwiftUI 的 onTap 可能收不到。
            // 所以，我们将点击逻辑移到 LongPressDraggable 内部其实很难。
            // 更好的做法：LongPressDraggable 作为 .background? 
            // 如果作为 background，UIView 可能收不到触摸？不，SwiftUI background 如果有 frame 就可以。
            // 但这里 LongPressDraggable 默认 frame .zero？ MakeUIView 里 frame .zero。
            // 我们需要它填充。
            
            // 3. Edit Buttons (Sibling, not inside main button)
            if isEditMode {
                editModeButtons
            }
        }
        .background(frameReporter)
        .opacity(dragCoordinator.draggedNodeId == node.id ? 0 : 1)
        .animation(.easeOut(duration: 0.14), value: dragCoordinator.draggedNodeId == node.id)
        .animation(.spring(response: 0.32, dampingFraction: 0.92), value: isCurrent)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragCoordinator.hoveringNodeId)
    }
    
    // MARK: - Frame Reporter
    
    private var frameReporter: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: NodeFrameKey.self,
                    value: [node.id: geo.frame(in: .global)]
                )
                .onAppear { nodeFrame = geo.frame(in: .global) }
                .onChange(of: geo.frame(in: .global)) { _, newFrame in nodeFrame = newFrame }
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
        switch state {
        case .began:
            // Long Press Succeeded (0.4s elapsed)
            // Start Drag
            if !appMode.isDragging {
                print("🚀 [UIKit] LongPress Began. Starting Drag...")
                Haptics.impact(.medium)
                isPressing = false
                
                let center = CGPoint(x: nodeFrame.midX, y: nodeFrame.midY)
                let start = location
                let offset = CGSize(width: center.x - start.x, height: center.y - start.y)
                
                let payload = DragPayload(type: .node(node.id), source: .library, initialOffset: offset)
                appMode.enter(.dragging(payload))
                dragCoordinator.startDrag(payload: payload)
            }
            dragCoordinator.dragLocation = location
            
        case .changed:
            if appMode.isDragging {
                dragCoordinator.dragLocation = location
            }
            
        case .ended, .cancelled, .failed:
            if appMode.isDragging {
                print("🛑 [UIKit] Drag Ended.")
                dragCoordinator.isDragEnded = true
            }
            isPressing = false
            
        default:
            break
        }
    }
}

// MARK: - Helper Style
// CardButtonStyle is already defined in Shared/ButtonStyles.swift
