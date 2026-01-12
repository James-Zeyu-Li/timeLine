import SwiftUI
import TimeLineCore

// MARK: - Timeline Node Sub-Components

/// Drag handle component (三道杠)
struct TimelineNodeDragHandle: View {
    let isDragging: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(PixelTheme.textSecondary.opacity(isDragging ? 0.8 : 0.4))
                    .frame(width: 12, height: 2)
            }
        }
        .padding(.trailing, 4)
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .animation(.spring(response: 0.2), value: isDragging)
    }
}

/// Icon badge component for timeline nodes
struct TimelineNodeIconBadge: View {
    let node: TimelineNode
    let isCurrent: Bool
    let isPulsing: Bool
    
    var body: some View {
        let (icon, color) = iconAndColor
        
        return ZStack {
            RoundedRectangle(cornerRadius: PixelTheme.cornerSmall)
                .fill(color.opacity(0.25))
                .frame(width: 38, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: PixelTheme.cornerSmall)
                        .stroke(color.opacity(0.6), lineWidth: PixelTheme.strokeThin)
                )
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .overlay(
            RoundedRectangle(cornerRadius: PixelTheme.cornerMedium)
                .stroke(isPulsing ? PixelTheme.accent : Color.clear, lineWidth: PixelTheme.strokeBold)
                .scaleEffect(isPulsing ? 1.35 : 1)
                .opacity(isPulsing ? 0.7 : 0)
        )
        .shadow(color: isCurrent ? color.opacity(0.6) : .clear, radius: 10, x: 0, y: 0)
    }
    
    private var iconAndColor: (String, Color) {
        switch node.type {
        case .battle(let boss):
            let icon = boss.style == .focus ? "bolt.fill" : "checkmark.circle.fill"
            return (icon, boss.category.color)
        case .bonfire:
            return ("flame.fill", .orange)
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
            if let absolute = timeInfo.absolute {
                Text(absolute)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(PixelTheme.accent)
            }
            if let relative = timeInfo.relative {
                Text(relative)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(PixelTheme.textSecondary)
            }
            if timeInfo.isRecommended {
                Text("RECOMMENDED")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(PixelTheme.accent)
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
    
    private var statusBadge: (text: String, color: Color)? {
        if isCurrent {
            return ("STARTED", .cyan)
        }
        if isNext {
            return ("NEXT", .green)
        }
        if node.isCompleted {
            return ("DONE", .gray)
        }
        if node.isLocked {
            return ("LOCKED", .orange)
        }
        return nil
    }
    
    private func statusBadgeView(_ badge: (text: String, color: Color)) -> some View {
        Text(badge.text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badge.color.opacity(0.2))
            .foregroundColor(badge.color)
            .cornerRadius(PixelTheme.cornerSmall)
    }
    
    private var finalBadgeView: some View {
        Text("FINAL")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.2))
            .foregroundColor(.purple)
            .cornerRadius(PixelTheme.cornerSmall)
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
        }
    }
    
    private var editButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                onHide()
            }
            onEdit()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                Text("Edit")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: actionButtonWidth, height: cardHeight)
            .background(Color.blue)
        }
        .accessibilityIdentifier("Edit")
    }
    
    private var duplicateButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                onHide()
            }
            onDuplicate()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .semibold))
                Text("Copy")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: actionButtonWidth, height: cardHeight)
            .background(Color.orange)
        }
        .accessibilityIdentifier("Copy")
    }
    
    private var deleteButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                onHide()
            }
            onDelete()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                Text("Delete")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: actionButtonWidth, height: cardHeight)
            .background(Color.red)
        }
        .accessibilityIdentifier("Delete")
    }
}

/// Card styling components
struct TimelineNodeCardStyling {
    static func background(isCurrent: Bool) -> some View {
        RoundedRectangle(cornerRadius: PixelTheme.cornerLarge)
            .fill(
                LinearGradient(
                    colors: [PixelTheme.cardTop, PixelTheme.cardBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    static func border(isCurrent: Bool) -> some View {
        RoundedRectangle(cornerRadius: PixelTheme.cornerLarge)
            .stroke(isCurrent ? PixelTheme.cardGlow : PixelTheme.cardBorder, lineWidth: isCurrent ? PixelTheme.strokeBold : PixelTheme.strokeThin)
            .shadow(
                color: isCurrent ? PixelTheme.cardGlow.opacity(0.6) : .clear,
                radius: PixelTheme.shadowRadius,
                x: PixelTheme.shadowOffset.width,
                y: PixelTheme.shadowOffset.height
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
                        .foregroundColor(PixelTheme.textPrimary)
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