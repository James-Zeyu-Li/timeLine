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
    let currentActiveId: UUID?
    let isEditMode: Bool
    @Binding var rowHeights: [UUID: CGFloat]
    
    // Callbacks
    let handleDragChanged: (DragGesture.Value, TimelineNode) -> Void
    let handleDragEnded: (DragGesture.Value, TimelineNode) -> Void
    let handleTap: (TimelineNode) -> Void
    let startEditing: (TimelineNode) -> Void
    let estimatedStartTime: (TimelineNode) -> (absolute: String, relative: String?)?
    
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    
    var body: some View {
        VStack(spacing: 0) {
            let currentId = currentActiveId
            let heroId = currentId ?? upcomingNodes.first?.id
            let firstUpcomingId = upcomingNodes.first?.id
            let secondUpcomingId = upcomingNodes.dropFirst().first?.id
            let nextAfterCurrentId: UUID? = {
                if let currentId = currentId,
                   let currentIndex = upcomingNodes.firstIndex(where: { $0.id == currentId }),
                   upcomingNodes.indices.contains(currentIndex + 1) {
                    return upcomingNodes[currentIndex + 1].id
                }
                return nil
            }()
            let hasAnySuggestedTime = upcomingNodes.contains { node in
                if case .battle(let boss) = node.type {
                    return boss.recommendedStart != nil
                }
                return false
            }
            let recommendedId: UUID? = {
                if currentId != nil {
                    return nextAfterCurrentId
                }
                return firstUpcomingId
            }()
            ForEach(Array(upcomingNodes.enumerated()), id: \.element.id) { _, node in
                let isDragging = draggingNodeId == node.id
                // Hero follows current task when available, otherwise first upcoming
                let isHeroNode = node.id == heroId
                let isActiveNode = node.id == currentId
                let hasSuggestedTime: Bool = {
                    if case .battle(let boss) = node.type {
                        return boss.recommendedStart != nil
                    }
                    return false
                }()
                let labelText: String? = {
                    if let currentId = currentId {
                        if node.id == currentId { return "STARTED" }
                        if node.id == nextAfterCurrentId { return "NEXT" }
                        return nil
                    }
                    if node.id == firstUpcomingId { return "FIRST" }
                    if node.id == secondUpcomingId { return "NEXT" }
                    return nil
                }()
                let isRecommended = hasSuggestedTime || (!hasAnySuggestedTime && node.id == recommendedId && node.id != currentId)
                
                let row = TimelineNodeView(
                    node: node,
                    isEditMode: isEditMode,
                    isHero: isHeroNode,
                    isActive: isActiveNode,
                    isLocked: node.isLocked,
                    onDragChanged: isEditMode ? { handleDragChanged($0, node) } : nil,
                    onDragEnded: isEditMode ? { handleDragEnded($0, node) } : nil
                )
                let rowWithOverlays = row
                    .overlay(alignment: .trailing) {
                        if draggingNodeId == nil, let estimate = estimatedStartTime(node) {
                            VStack(alignment: .trailing, spacing: 2) {
                                if isRecommended {
                                    Text("RECOMMENDED")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(0.8)
                                        .foregroundColor(.cyan.opacity(0.9))
                                }
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
                    .overlay(alignment: .topLeading) {
                        if let label = labelText {
                            Text(label)
                                .font(.system(size: label == "FIRST" ? 10 : 9, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(labelBackground(label))
                                .cornerRadius(8)
                                .padding(.leading, 24)
                                .padding(.top, 10)
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
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: NodeFrameKey.self, value: [node.id: geo.frame(in: .global)])
                    })
                    .overlay(
                        Group {
                            if isDragging {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                                    .shadow(color: .cyan.opacity(0.3), radius: 8)
                            }
                        }
                    )
                    .opacity(isDragging ? 0.9 : 1.0)
                    .scaleEffect(isDragging ? 1.02 : 1.0)
                    .offset(isDragging ? dragOffset : .zero)
                    .contentShape(Rectangle())
                    .padding(.bottom, 8)
                
                if isEditMode {
                    rowWithOverlays
                } else {
                    rowWithOverlays
                        .onTapGesture {
                            guard !isInteractionLocked else { return }
                            handleTap(node)
                        }
                        .contextMenu {
                            Button {
                                startEditing(node)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button {
                                let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
                                timelineStore.duplicateNode(id: node.id)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            
                            if !node.isCompleted && !node.isLocked {
                                Button(role: .destructive) {
                                    let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
                                    timelineStore.deleteNode(id: node.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
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
                                    let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
                                    timelineStore.deleteNode(id: node.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .onPreferenceChange(RowHeightPreferenceKey.self) { rowHeights = $0 }
        }
    }
    
    private func labelBackground(_ label: String) -> Color {
        switch label {
        case "STARTED":
            return Color.green.opacity(0.22)
        case "FIRST":
            return Color.orange.opacity(0.22)
        default:
            return Color.cyan.opacity(0.18)
        }
    }
}
