import SwiftUI
import TimeLineCore

// MARK: - Timeline Node Sub-Components

/// Drag handle component (三道杠)
struct TimelineNodeDragHandle: View {
    let isDragging: Bool
    
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(PixelTheme.textSecondary.opacity(isDragging ? 0.8 : 0.3))
                    .frame(width: 14, height: 2)
            }
        }
        .padding(.trailing, 8)
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .animation(.spring(response: 0.2), value: isDragging)
    }
}

/// Icon badge component (Clean Circle Style)
struct TimelineNodeIconBadge: View {
    let node: TimelineNode
    let isCurrent: Bool
    let isPulsing: Bool
    
    var body: some View {
        let (icon, color) = iconAndColor
        
        return ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 40, height: 40)
                
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
        }
        .overlay(
            Circle()
                .stroke(isPulsing ? PixelTheme.primary : Color.clear, lineWidth: 2)
                .scaleEffect(isPulsing ? 1.2 : 1)
                .opacity(isPulsing ? 0.6 : 0)
        )
    }
    
    private var iconAndColor: (String, Color) {
        switch node.type {
        case .battle(let boss):
            return (boss.category.icon, boss.category.color)
        case .bonfire:
            return ("flame.fill", PixelTheme.primary)
        case .treasure:
            return ("star.fill", .yellow)
        }
    }
}

/// Time information display component
struct TimelineNodeTimeInfo: View {
    let timeInfo: MapTimeInfo
    
    var body: some View {
        HStack(spacing: 6) {
            if timeInfo.isRecommended {
                Text("RECOMMENDED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(PixelTheme.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(PixelTheme.primary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            if let relative = timeInfo.relative {
                HStack(spacing: 4) {
                    if relative.contains("min") {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                    }
                    Text(relative)
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.medium)
                }
                .foregroundColor(PixelTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
            }
            
            if let absolute = timeInfo.absolute {
                Text(absolute)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(PixelTheme.textSecondary.opacity(0.7))
            }
        }
    }
}

/// Status badge component
struct TimelineNodeStatusBadge: View {
    let node: TimelineNode
    let isCurrent: Bool
    let isNext: Bool
    let isFinal: Bool
    
    var body: some View {
        Group {
            if let badge = statusBadge {
                statusBadgeView(badge)
            } else if isFinal {
                finalBadgeView
            }
        }
    }
    
    private var statusBadge: (text: String?, color: Color)? {
        if isCurrent {
            return ("IN PROGRESS", PixelTheme.primary)
        }
        if isNext {
            return ("NEXT UP", PixelTheme.success)
        }
        if node.isCompleted {
            return (nil, PixelTheme.textSecondary) // Use tick icon instead
        }
        if node.isLocked {
            return ("LOCKED", PixelTheme.textSecondary.opacity(0.5))
        }
        return nil
    }
    
    @ViewBuilder
    private func statusBadgeView(_ badge: (text: String?, color: Color)) -> some View {
        if let text = badge.text {
            Text(text)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badge.color.opacity(0.1))
                .foregroundColor(badge.color)
                .cornerRadius(4)
        } else {
            // Completed tick
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(PixelTheme.success)
        }
    }
    
    private var finalBadgeView: some View {
        Text("FINAL")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(PixelTheme.warning.opacity(0.1))
            .foregroundColor(PixelTheme.warning)
            .cornerRadius(4)
    }
}

/// Edit action buttons component
struct TimelineNodeEditActions: View {
    let alignment: MapNodeAlignment
    let cardHeight: CGFloat
    let cardOffsetX: CGFloat
    let actionButtonWidth: CGFloat
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onHide: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            
            HStack(spacing: 0) {
                editButton
                duplicateButton
                deleteButton
            }
            .offset(x: alignment == .left ? cardOffsetX : -cardOffsetX)
            .clipShape(RoundedRectangle(cornerRadius: 12)) 
        }
    }
    
    private var editButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) { onHide() }
            onEdit()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "pencil")
                Text("Edit").font(.system(size: 10))
            }
            .foregroundColor(.white)
            .frame(width: actionButtonWidth, height: cardHeight)
            .background(PixelTheme.secondary)
        }
    }
    
    private var duplicateButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) { onHide() }
            onDuplicate()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                Text("Copy").font(.system(size: 10))
            }
            .foregroundColor(.white)
            .frame(width: actionButtonWidth, height: cardHeight)
            .background(PixelTheme.secondary.opacity(0.7))
        }
    }
    
    private var deleteButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) { onHide() }
            onDelete()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "trash")
                Text("Delete").font(.system(size: 10))
            }
            .foregroundColor(.white)
            .frame(width: actionButtonWidth, height: cardHeight)
            .background(PixelTheme.warning)
        }
    }
}

/// Card styling components (Clean Card Style)
struct TimelineNodeCardStyling {
    static func background(isCurrent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white)
            .shadow(
                color: isCurrent ? PixelTheme.primary.opacity(0.2) : Color.black.opacity(0.04),
                radius: isCurrent ? 12 : 6,
                x: 0,
                y: isCurrent ? 4 : 2
            )
    }
    
    static func border(isCurrent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                isCurrent ? PixelTheme.primary : Color.black.opacity(0.03),
                lineWidth: isCurrent ? 2 : 1
            )
    }
}

/// Drop target overlay component
struct TimelineNodeDropTarget: View {
    let node: TimelineNode
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    var body: some View {
        Group {
            if appMode.isDragging {
                let isHovering = dragCoordinator.hoveringNodeId == node.id
                RoundedRectangle(cornerRadius: PixelTheme.cornerLarge)
                    .stroke(
                        isHovering ? PixelTheme.accent : Color.white.opacity(0.15),
                        lineWidth: isHovering ? PixelTheme.strokeBold + 1 : PixelTheme.strokeThin
                    )
                    .shadow(color: isHovering ? PixelTheme.accent.opacity(0.6) : .clear, radius: 8, x: 0, y: 0)
                    .allowsHitTesting(false)
                    .overlay(alignment: .bottom) {
                        if isHovering {
                            InsertHint(placement: dragCoordinator.hoveringPlacement)
                                .padding(.bottom, 8)
                        }
                    }
            }
        }
    }
}

/// Deck ghost overlay component
struct TimelineNodeDeckGhost: View {
    let node: TimelineNode
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    var body: some View {
        Group {
            if appMode.isDragging,
               let summary = dragCoordinator.activeDeckSummary,
               dragCoordinator.hoveringNodeId == node.id {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Insert \(summary.count)")
                        .font(.system(size: 10, weight: .bold))
                    Text("·")
                        .font(.system(size: 10, weight: .bold))
                    Text(formatDuration(summary.duration))
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(.trailing, 12)
                .padding(.top, 10)
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return "\(minutes) min"
    }
}

/// Background elements component
struct TimelineNodeBackground: View {
    let node: TimelineNode
    let alignment: MapNodeAlignment
    let isNext: Bool
    let isCurrent: Bool
    let terrainWidth: CGFloat
    let terrainHeight: CGFloat
    
    var body: some View {
        ZStack {
            PixelTrail()
                .frame(width: PixelTheme.baseUnit * 1.5)
                .frame(maxHeight: .infinity)
            
            PixelTerrainTile(type: PixelTerrainType(from: node))
                .frame(width: terrainWidth, height: terrainHeight)
                .opacity(0.35)
                .offset(y: 18)
            
            if showHeroMarker {
                PixelHeroMarker()
                    .offset(x: alignment == .left ? -120 : 120, y: -24)
            }
        }
    }
    
    private var showHeroMarker: Bool {
        isNext && !isCurrent && !node.isCompleted
    }
}

/// Main node content component
struct TimelineNodeMainContent: View {
    let node: TimelineNode
    let alignment: MapNodeAlignment
    let isCurrent: Bool
    let isNext: Bool
    let isFinal: Bool
    let isPulsing: Bool
    let timeInfo: MapTimeInfo?
    let isDragging: Bool
    let swipeOffset: CGFloat
    let dragOffset: CGSize
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let cardOffsetX: CGFloat
    let preventTap: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onPreventTap: (Bool) -> Void
    
    @EnvironmentObject var appMode: AppModeManager
    
    var body: some View {
        Button(action: {
            if preventTap {
                onPreventTap(false)
                return
            }
            onTap()
        }) {
            HStack(spacing: 12) {
                // Drag handle (三道杠)
                TimelineNodeDragHandle(isDragging: isDragging)
                
                // Icon badge
                TimelineNodeIconBadge(
                    node: node,
                    isCurrent: isCurrent,
                    isPulsing: isPulsing
                )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(PixelTheme.textInverted)
                        .lineLimit(1)
                    
                    if let timeInfo {
                        TimelineNodeTimeInfo(timeInfo: timeInfo)
                    }
                }
                
                Spacer()
                
                // Status badge
                TimelineNodeStatusBadge(
                    node: node,
                    isCurrent: isCurrent,
                    isNext: isNext,
                    isFinal: isFinal
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: cardWidth, height: cardHeight)
            .background(TimelineNodeCardStyling.background(isCurrent: isCurrent))
            .overlay(TimelineNodeCardStyling.border(isCurrent: isCurrent))
            .overlay(TimelineNodeDropTarget(node: node))
            .overlay(TimelineNodeDeckGhost(node: node), alignment: .topTrailing)
            .opacity(node.isLocked ? 0.45 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(nodeAccessibilityId)
        .offset(x: alignment == .left ? -cardOffsetX : cardOffsetX)
        .offset(x: swipeOffset + (isDragging ? 0 : dragOffset.width), y: dragOffset.height)
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: swipeOffset)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    guard canEditNode, !appMode.isDragging else { return }
                    onPreventTap(true)
                    onLongPress()
                }
        )
    }
    
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
    
    private var canEditNode: Bool {
        if case .battle = node.type {
            return true
        }
        return false
    }
}