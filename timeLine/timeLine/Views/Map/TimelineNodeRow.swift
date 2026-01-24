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
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // MARK: - Left Axis (Timeline + Icon)
            ZStack {
                // 1. The vertical line (background, full height)
                timelineLineOnly
                
                // 2. Icon + Time Marker stacked vertically (Icon on Top)
                VStack(spacing: 4) { // Reduced spacing slightly since Icon is top
                    nodeIconView
                    timeMarkerView
                }
                .padding(.top, isCurrent ? 24 : 12) // Keep padding logic
            }
            .frame(width: 50) // Increased from 44 to 50 to fit "Finished" text

            
            
            // MARK: - Draggable Content (Card Body)
            HStack(alignment: .top, spacing: 0) {
                // OLD Icon position removed from here
                
                // MARK: - Main Content
                if isCurrent {
                    currentTaskCard
                } else {
                    compactTaskCard
                }
                
                // MARK: - Edit Mode Buttons
                if isEditMode {
                    editModeButtons
                }
            }
            // Interaction Logic:
            // 1. Current Task: No row-level tap. User uses the Play Button.
            // 2. Future Task: Tap allowed via compactTaskCard credential.
            // Long press to start drag mode.
            // NOTE: We apply LongPress to the content, but we must ensure it doesn't swallow Button touches.
            // Removing contentShape(Rectangle()) to avoid capturing empty space touches unnecessarily.
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 8) {
                // Start drag mode
                let payload = DragPayload(type: .node(node.id), source: .library)
                appMode.enter(.dragging(payload))
                dragCoordinator.startDrag(payload: payload)
                Haptics.impact(.medium)
            }
            .scaleEffect(dragCoordinator.draggedNodeId == node.id ? 1.05 : 1.0)
            .shadow(
                color: dragCoordinator.draggedNodeId == node.id ? .black.opacity(0.3) : .clear,
                radius: dragCoordinator.draggedNodeId == node.id ? 8 : 0,
                x: 0,
                y: dragCoordinator.draggedNodeId == node.id ? 4 : 0
            )
            .offset(
                x: dragCoordinator.draggedNodeId == node.id ? dragCoordinator.dragOffset.width : 0,
                y: dragCoordinator.draggedNodeId == node.id ? dragCoordinator.dragOffset.height : 0
            )
            .zIndex(dragCoordinator.draggedNodeId == node.id ? 1000 : 0)
            .animation(.easeInOut(duration: 0.2), value: dragCoordinator.draggedNodeId == node.id)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCurrent)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragCoordinator.hoveringNodeId)
        }
        .background(frameReporter)
    }
    
    // MARK: - Frame Reporter
    
    private var frameReporter: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: NodeFrameKey.self,
                    value: [node.id: geo.frame(in: .global)]
                )
        }
    }
    
    
    // MARK: - Timeline Line Only (Background)
    
    private var timelineLineOnly: some View {
        PathLine(isCompleted: node.isCompleted, isCurrent: isCurrent)
            .frame(width: 40)
            .frame(maxHeight: .infinity)
    }
    
    private var timeMarkerView: some View {
        VStack(spacing: 2) {
            if isCurrent {
                // Current task: Show "NOW"
                Text("NOW")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(PixelTheme.accent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(PixelTheme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(PixelTheme.accent, lineWidth: 1)
                    )
            } else if let timeInfo = estimatedTimeInfo {
                // Future tasks or Completed tasks
                Text(timeInfo)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center) // Center align for multi-line
                    .foregroundColor(node.isCompleted ? PixelTheme.textSecondary : PixelTheme.textSecondary.opacity(0.8))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    // Remove background for cleaner look on completed tasks? 
                    // Or keep it consistent. Let's keep consistent.
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(PixelTheme.cardBackground.opacity(0.8))
                    )
            }
        }
    }
    
    private var estimatedTimeInfo: String? {
        // Return the passed-in estimated time label
        // Allow simplified return since RogueMapView handles the logic (including nil for current)
        return estimatedTimeLabel
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
    
    private var nodeIconView: some View {
        ZStack {
            // Shadow for depth
            Circle()
                .fill(Color.black.opacity(0.15))
                .frame(width: iconSize + 4, height: iconSize + 4)
                .offset(y: 2)
            
            // Background circle with border
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: iconSize, height: iconSize)
                .overlay(
                    Circle()
                        .stroke(PixelTheme.primary.opacity(0.1), lineWidth: 1)
                )
            
            // Icon
            Image(systemName: iconName)
                .font(.system(size: iconImageSize, weight: .bold))
                .foregroundColor(iconForegroundColor)
        }
    }
    
    // MARK: - Current Task Card (Large, Detailed)
    
    private var currentTaskCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // IN PROGRESS Label
            HStack {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(PixelTheme.primary)
                
                Text(currentTaskStatusText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(PixelTheme.primary)
                    .tracking(0.5)
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PixelTheme.textSecondary)
                }
            }
            
            // Task Title
            Text(nodeTitle)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(PixelTheme.textPrimary)
                .lineLimit(2)
            
            // Task Description
            Text(taskDescription)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(PixelTheme.textSecondary)
                .lineLimit(3)
            
            // Time and Action Section
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME REMAINING")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(PixelTheme.textSecondary)
                        .tracking(0.5)
                    
                    Text(timeRemaining)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(PixelTheme.textPrimary)
                }
                
                Spacer()
                
                // Play Button
                Button(action: onTap) {
                    ZStack {
                        Circle()
                            .fill(PixelTheme.primary)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 2) // Slight offset for visual balance
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(BounceButtonStyle()) // Adds press effect
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PixelTheme.cardBackground)
                .stroke(PixelTheme.primary, lineWidth: 2)
        )
        // Reduced horizontal padding to 16 only (removed duplicate)
        .padding(.horizontal, 16)
        // Applied negative top padding to raise the card closer to the next task
        // REVERTED: Negative padding caused overlap. Using standard padding.
        .padding(.top, 0)
        .padding(.bottom, 12)
    }
    
    // MARK: - Compact Task Card (Small, Less Detail)
    
    private var compactTaskCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(nodeTitle)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(node.isCompleted ? PixelTheme.textSecondary : compactTaskTextColor)
                    .strikethrough(node.isCompleted)
                    .lineLimit(1)
                
                Text(compactSubtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(compactTaskSecondaryTextColor)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Right side info
            if node.isCompleted {
                Text(compactSubtitle) // Use the same logic as compactSubtitle
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(PixelTheme.success.opacity(compactTaskOpacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PixelTheme.cardBackground.opacity(compactTaskOpacity))
        )
        // REMOVED Tap Gesture for compact/future nodes to force sequential progression
        // User rule: Only "Play" button on current task starts activity.
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Computed Properties
    
    private var nodeTitle: String {
        switch node.type {
        case .battle(let boss):
            return boss.name
        case .bonfire:
            return "Rest Point"
        case .treasure:
            return "Treasure Chest"
        }
    }
    
    private var compactSubtitle: String {
        switch node.type {
        case .battle(let boss):
            if node.isCompleted {
                return "Completed +15 XP"
            } else {
                let minutes = Int(boss.maxHp / 60)
                return "Future Quest • \(minutes)m"
            }
        case .bonfire(let duration):
            return "Rest Point (+10 HP) • \(Int(duration/60))m"
        case .treasure:
            return "Bonus Loot"
        }
    }
    
    private var taskDescription: String {
        switch node.type {
        case .battle:
            // Show actual progress data instead of motivational quotes
            let focusedMinutes = Int(engine.totalFocusedToday / 60)
            let completedTasks = daySession.nodes.filter { node in
                node.isCompleted && {
                    switch node.type {
                    case .battle: return true
                    default: return false
                    }
                }()
            }.count
            
            if focusedMinutes > 0 || completedTasks > 0 {
                var parts: [String] = []
                
                if focusedMinutes > 0 {
                    parts.append("\(focusedMinutes) minutes focused today")
                }
                
                if completedTasks > 0 {
                    parts.append("\(completedTasks) task\(completedTasks == 1 ? "" : "s") completed")
                }
                
                return parts.joined(separator: " • ")
            } else {
                return "Ready to start your first focus session today"
            }
        case .bonfire:
            return "Take a well-deserved break. Recharge for the next challenge."
        case .treasure:
            return "Open to claim your rewards and continue your journey."
        }
    }
    
    private var timeRemaining: String {
        switch node.type {
        case .battle(let boss):
            let minutes = Int(boss.maxHp / 60)
            return "\(minutes) mins"
        case .bonfire(let duration):
            let minutes = Int(duration / 60)
            return "\(minutes) mins"
        case .treasure:
            return "0 mins"
        }
    }
    
    // MARK: - Icon Properties
    
    private var iconName: String {
        switch node.type {
        case .battle:
            if node.isCompleted {
                return "checkmark"
            } else {
                return "person.fill"
            }
        case .bonfire:
            return "flame.fill"
        case .treasure:
            return "gift.fill"
        }
    }
    
    private var iconSize: CGFloat {
        if isCurrent {
            return 32
        } else {
            return 24
        }
    }
    
    private var iconImageSize: CGFloat {
        if isCurrent {
            return 16
        } else {
            return 12
        }
    }
    
    private var iconBackgroundColor: Color {
        if isCurrent {
            return PixelTheme.primary
        } else if node.isCompleted {
            return PixelTheme.secondary // Use Secondary (Brown/Wood) for completed instead of faded Green
        } else {
            return PixelTheme.textSecondary.opacity(0.3 * compactTaskOpacity)
        }
    }
    
    private var iconForegroundColor: Color {
        if isCurrent || node.isCompleted {
            return .white // Always white, no opacity fade for completed
        } else {
            return PixelTheme.textSecondary.opacity(compactTaskOpacity)
        }
    }
    
    private var currentTaskStatusText: String {
        return "CURRENT QUEST"
    }
    
    // MARK: - Compact Task Styling
    
    private var compactTaskOpacity: Double {
        // Dim non-current tasks
        return isCurrent ? 1.0 : 0.7
    }
    
    private var compactTaskTextColor: Color {
        return PixelTheme.textPrimary.opacity(compactTaskOpacity)
    }
    
    private var compactTaskSecondaryTextColor: Color {
        return PixelTheme.textSecondary.opacity(compactTaskOpacity)
    }
}

// MARK: - Helper Views

// MARK: - Helper Views

private struct PathLine: View {
    let isCompleted: Bool
    let isCurrent: Bool
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background track (always faint dashed)
                Path { path in
                    path.move(to: CGPoint(x: proxy.size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: proxy.size.width / 2, y: proxy.size.height))
                }
                .stroke(PixelTheme.primary.opacity(0.15), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 10]))
                
                // Progress track (Solid if completed)
                if isCompleted || isCurrent {
                    Path { path in
                        path.move(to: CGPoint(x: proxy.size.width / 2, y: 0))
                        // If current, only draw half way (to the node center)
                        // If completed, draw full way? 
                        // Visual choice: Completed nodes show full path TRAVERSED.
                        // Current node shows path reaching it.
                        let endY = isCurrent ? proxy.size.height / 2 : proxy.size.height
                        path.addLine(to: CGPoint(x: proxy.size.width / 2, y: endY))
                    }
                    .stroke(PixelTheme.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
                
                // For completed nodes, we want the path to continue THROUGH them to the next one
                // But since line is drawn from Top to Bottom, and we are in a reversed list...
                // Actually, just ensuring the line itself is fully opaque is enough.
                // The PathLine stroke above uses PixelTheme.primary which is opaque.
            }
            .opacity(1.0) // Force full opacity for the line, ignoring parent opacity
        }
    }
}

// MARK: - Helper Styles

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
