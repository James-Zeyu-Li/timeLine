import SwiftUI
import TimeLineCore

// MARK: - Row Height Preference Key
struct RowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct UpcomingNodeListView: View {
    let upcomingNodes: [TimelineNode]
    let draggingNodeId: UUID?
    let dragOffset: CGSize
    let pulseNextNodeId: UUID?
    let isInteractionLocked: Bool
    @Binding var rowHeights: [UUID: CGFloat]
    
    // Callbacks
    let handleDragChanged: (DragGesture.Value, TimelineNode) -> Void
    let handleDragEnded: (DragGesture.Value, TimelineNode) -> Void
    let handleTap: (TimelineNode) -> Void
    let startEditing: (TimelineNode) -> Void
    let estimatedStartTime: (TimelineNode) -> (absolute: String, relative: String?)?
    
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    
    // Track long press progress (0.0 to 1.0) for gradual visual feedback
    @State private var longPressProgress: [UUID: CGFloat] = [:]
    @State private var longPressTimer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(upcomingNodes.enumerated()), id: \.element.id) { index, node in
                let isDragging = draggingNodeId == node.id
                // Hero always applies to FIRST node in upcoming list (index 0)
                let isHeroNode = index == 0
                let isActiveNode = node.id == daySession.currentNode?.id
                
                TimelineNodeView(
                    node: node,
                    isEditMode: false,
                    isHero: isHeroNode,
                    isActive: isActiveNode,
                    isLocked: node.isLocked,
                    onDragChanged: nil,
                    onDragEnded: nil
                )
                .overlay(alignment: .trailing) {
                    if draggingNodeId == nil, let estimate = estimatedStartTime(node) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(estimate.absolute)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.gray)
                            if let rel = estimate.relative {
                                Text(rel)
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                                    .foregroundColor(.gray.opacity(0.8))
                            }
                        }
                        .padding(.trailing, 24)
                        // Fade out during drag
                        .transition(.opacity)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        // Pause pulse during drag
                        .stroke(Color.cyan.opacity((pulseNextNodeId == node.id && draggingNodeId == nil) ? 0.6 : 0), lineWidth: 2)
                        .scaleEffect((pulseNextNodeId == node.id && draggingNodeId == nil) ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: (pulseNextNodeId == node.id && draggingNodeId == nil))
                )
                .background(GeometryReader { geo in
                    Color.clear.preference(key: RowHeightPreferenceKey.self, value: [node.id: geo.size.height])
                })
                .overlay(
                    Group {
                        let progress = longPressProgress[node.id] ?? 0
                        if isDragging {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                                .shadow(color: .cyan.opacity(0.3), radius: 8)
                        } else if progress > 0 {
                            // Long press feedback: gradual glowing border
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.3 + Double(progress) * 0.4), lineWidth: 1 + progress)
                                .shadow(color: .cyan.opacity(Double(progress) * 0.5), radius: 8 + progress * 8)
                        }
                    }
                )
                .brightness(Double(longPressProgress[node.id] ?? 0) * 0.15)  // Gradual brighten
                .opacity(isDragging ? 0.9 : 1.0)
                .scaleEffect(
                    isDragging ? 1.02 : (1.0 + Double(longPressProgress[node.id] ?? 0) * 0.03)
                )
                .offset(
                    isDragging ? dragOffset : CGSize(width: 0, height: -Double(longPressProgress[node.id] ?? 0) * 8)
                )
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                    if isPressing {
                        // Touch down - start gradual feedback
                        startLongPressProgress(for: node.id)
                    } else {
                        // Touch up/cancelled - stop feedback
                        cancelLongPress(for: node.id)
                    }
                }, perform: {})
                // Long press (1s) + Drag gesture for reordering
                .gesture(
                    LongPressGesture(minimumDuration: 1.0)
                        .onEnded { _ in
                            // Long press completed - trigger success haptic
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                        .sequenced(before: DragGesture(minimumDistance: 5, coordinateSpace: .named("scroll")))
                        .onChanged { value in
                            switch value {
                            case .second(true, let drag):
                                if let drag = drag {
                                    // Drag started - stop progress and clear feedback
                                    stopLongPressProgress(for: node.id)
                                    handleDragChanged(drag, node)
                                }
                            default:
                                break
                            }
                        }
                        .onEnded { value in
                            // Drag ended
                            stopLongPressProgress(for: node.id)
                            
                            switch value {
                            case .second(true, let drag):
                                if let drag = drag {
                                    handleDragEnded(drag, node)
                                }
                            default:
                                break
                            }
                        }
                )
                .padding(.bottom, 8)
                .onTapGesture {
                    guard !isInteractionLocked else { return }
                    handleTap(node)
                }
                // Swipe left to edit
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        startEditing(node)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                    
                    if !node.isCompleted && !node.isLocked {
                        Button(role: .destructive) {
                            daySession.deleteNode(id: node.id)
                            stateManager.requestSave()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .onPreferenceChange(RowHeightPreferenceKey.self) { rowHeights = $0 }
        }
    }
    
    // MARK: - Long Press Progress Helpers
    
    private func startLongPressProgress(for nodeId: UUID) {
        // Light haptic on touch down
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // Reset progress
        longPressProgress[nodeId] = 0
        
        // Animate progress from 0 to 1 over 1 second
        let startTime = Date()
        let duration: TimeInterval = 1.0
        
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            
            longPressProgress[nodeId] = CGFloat(progress)
            
            // Medium haptic at 50% progress
            if progress >= 0.5 && progress < 0.55 {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            
            if progress >= 1.0 {
                timer.invalidate()
            }
        }
    }
    
    private func stopLongPressProgress(for nodeId: UUID) {
        longPressTimer?.invalidate()
        longPressTimer = nil
        
        withAnimation(.easeOut(duration: 0.2)) {
            longPressProgress[nodeId] = nil
        }
    }
    
    private func cancelLongPress(for nodeId: UUID) {
        stopLongPressProgress(for: nodeId)
    }
}