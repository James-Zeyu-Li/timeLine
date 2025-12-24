import SwiftUI
import Combine
import TimeLineCore

// MARK: - Swipeable Timeline Node

/// 可滑动和拖拽的Timeline节点组件
/// 支持左滑编辑、拖拽重排等交互功能
struct SwipeableTimelineNode: View {
    
    // MARK: - Properties
    
    let node: TimelineNode
    let isEditMode: Bool
    
    @EnvironmentObject private var daySession: DaySession
    @EnvironmentObject private var stateManager: AppStateManager
    @EnvironmentObject private var engine: BattleEngine
    
    // MARK: - State
    
    @State private var dragOffset: CGSize = .zero
    @State private var showingEditActions = false
    @State private var showingEditSheet = false
    @State private var templateToEdit: TaskTemplate?
    
    // MARK: - Constants
    
    private enum Constants {
        static let maxSwipeDistance: CGFloat = -120
        static let swipeThreshold: CGFloat = -60
        static let iconSize: CGFloat = 20
        static let circleSize: CGFloat = 50
        static let glowRadius: CGFloat = 40
    }
    
    // MARK: - Computed Properties
    
    private var isActive: Bool {
        node.id == daySession.currentNode?.id
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            dragHandle
            mainContent
            editActions
        }
        .offset(x: dragOffset.width)
        .gesture(swipeGesture)
        .onTapGesture(perform: handleTap)
        .sheet(isPresented: $showingEditSheet) {
            editSheet
        }
    }
}

// MARK: - View Components

private extension SwipeableTimelineNode {
    
    var dragHandle: some View {
        DragHandle()
            .opacity(handleOpacity)
            .animation(.easeInOut(duration: 0.2), value: showingEditActions)
            .animation(.easeInOut(duration: 0.2), value: isEditMode)
    }
    
    var mainContent: some View {
        HStack(spacing: 20) {
            nodeIcon
            textContent
            Spacer()
            statusIndicator
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(backgroundGradient)
        .opacity(node.isLocked ? 0.3 : 1.0)
    }
    
    var nodeIcon: some View {
        ZStack {
            if isActive {
                activeGlow
            }
            iconBackground
            iconCircle
            iconImage
        }
    }
    
    var activeGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [nodeColor.opacity(0.4), nodeColor.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: Constants.glowRadius
                )
            )
            .frame(width: 80, height: 80)
    }
    
    var iconBackground: some View {
        Circle()
            .fill(Color.black)
            .frame(width: 58, height: 58)
    }
    
    var iconCircle: some View {
        Circle()
            .fill(nodeBackgroundColor)
            .frame(width: Constants.circleSize, height: Constants.circleSize)
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: isActive ? 3 : 2)
            )
            .shadow(color: isActive ? nodeColor.opacity(0.5) : .clear, radius: 8)
    }
    
    var iconImage: some View {
        Image(systemName: iconName)
            .font(.system(size: Constants.iconSize, weight: isActive ? .bold : .regular))
            .foregroundColor(iconColor)
            .scaleEffect(isActive ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isActive)
    }
    
    var textContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleText
            if shouldShowDetails {
                detailBadges
            } else if node.isLocked {
                lockedIndicator
            }
        }
    }
    
    var titleText: some View {
        Text(title)
            .font(.system(.headline, design: .rounded))
            .fontWeight(isActive ? .bold : .semibold)
            .foregroundColor(textColor)
            .strikethrough(node.isCompleted)
    }
    
    var detailBadges: some View {
        HStack(spacing: 8) {
            if case .battle(let boss) = node.type {
                taskTypeBadge(for: boss)
                categoryBadge(for: boss.category)
            }
        }
    }
    
    var lockedIndicator: some View {
        Text("Locked")
            .font(.system(.caption2, design: .rounded))
            .foregroundColor(.gray.opacity(0.6))
    }
    
    var statusIndicator: some View {
        Group {
            if node.isCompleted {
                completedIndicator
            } else if node.isLocked {
                lockedStatusIndicator
            }
        }
    }
    
    var completedIndicator: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 32, height: 32)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
        }
    }
    
    var lockedStatusIndicator: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.1))
                .frame(width: 32, height: 32)
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    var editActions: some View {
        if showingEditActions || isEditMode {
            EditActionsView(
                node: node,
                onEdit: startEditing,
                onDuplicate: duplicateNode,
                onDelete: deleteNode
            )
            .transition(.move(edge: .trailing))
        }
    }
    
    var editSheet: some View {
        TaskSheet(templateToEdit: $templateToEdit, isEditingNode: true) { updatedTemplate in
            let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
            timelineStore.updateNode(id: node.id, payload: updatedTemplate)
            templateToEdit = nil
        }
    }
}

// MARK: - Helper Methods

private extension SwipeableTimelineNode {
    
    var handleOpacity: Double {
        isEditMode ? 1.0 : (showingEditActions ? 1.0 : 0.4)
    }
    
    var shouldShowDetails: Bool {
        isActive || node.isCompleted
    }
    
    var backgroundGradient: LinearGradient {
        isActive ?
            LinearGradient(
                colors: [nodeColor.opacity(0.05), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            ) :
            LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
    }
    
    var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isEditMode, value.translation.width < 0 else { return }
                handleSwipeChanged(value)
            }
            .onEnded { value in
                guard !isEditMode else { return }
                handleSwipeEnded(value)
            }
    }
    
    func taskTypeBadge(for boss: Boss) -> some View {
        let (icon, text, color) = boss.style == .passive ? 
            ("checkmark.circle.fill", "Passive Task", Color.cyan) :
            ("clock.fill", "\(Int(boss.maxHp / 60)) min", Color.orange)
        
        return TagBadge(icon: icon, text: text, color: color)
    }
    
    func categoryBadge(for category: TaskCategory) -> some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.system(size: 9))
            Text(category.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
        }
        .foregroundColor(.gray)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(white: 0.15))
        .cornerRadius(4)
    }
}

// MARK: - Actions

private extension SwipeableTimelineNode {
    
    func handleTap() {
        if showingEditActions && !isEditMode {
            hideEditActions()
        } else if !isEditMode {
            executeNodeAction()
        }
    }
    
    func handleSwipeChanged(_ value: DragGesture.Value) {
        let newWidth = max(value.translation.width, Constants.maxSwipeDistance)
        dragOffset = CGSize(width: newWidth, height: 0)
        
        if newWidth < Constants.swipeThreshold && !showingEditActions {
            showEditActions()
        }
    }
    
    func handleSwipeEnded(_ value: DragGesture.Value) {
        withAnimation(.spring(response: 0.4)) {
            if dragOffset.width < Constants.swipeThreshold {
                dragOffset = CGSize(width: Constants.maxSwipeDistance, height: 0)
                showingEditActions = true
            } else {
                hideEditActions()
            }
        }
    }
    
    func showEditActions() {
        withAnimation(.spring(response: 0.3)) {
            showingEditActions = true
        }
        
        HapticFeedback.light()
    }
    
    func hideEditActions() {
        withAnimation(.spring(response: 0.4)) {
            dragOffset = .zero
            showingEditActions = false
        }
    }
    
    func executeNodeAction() {
        guard node.id == daySession.currentNode?.id, 
              !node.isLocked, 
              !node.isCompleted else { return }
        
        switch node.type {
        case .battle(let boss):
            engine.startBattle(boss: boss)
        case .bonfire(let duration):
            engine.startRest(duration: duration)
        case .treasure:
            break // No action for treasure nodes
        }
    }
    
    func startEditing() {
        guard case .battle(let boss) = node.type else { return }
        
        templateToEdit = TaskTemplate(
            id: boss.id,
            title: boss.name,
            style: boss.style,
            duration: boss.maxHp,
            repeatRule: .none,
            category: boss.category
        )
        showingEditSheet = true
        hideEditActions()
    }
    
    func duplicateNode() {
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.duplicateNode(id: node.id)
        hideEditActions()
    }
    
    func deleteNode() {
        guard !node.isCompleted && !node.isLocked else { return }
        
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.deleteNode(id: node.id)
        hideEditActions()
    }
}

// MARK: - Computed Properties for Styling

private extension SwipeableTimelineNode {
    
    var nodeColor: Color {
        switch node.type {
        case .battle(let boss):
            return boss.style == .passive ? .blue : .red
        case .bonfire: 
            return .orange
        case .treasure: 
            return .yellow
        }
    }
    
    var nodeBackgroundColor: Color {
        node.isCompleted ? Color(white: 0.1) : Color.black
    }
    
    var borderColor: Color {
        if isActive { return .white }
        if node.isCompleted { return Color(white: 0.3) }
        return nodeColor.opacity(0.5)
    }
    
    var iconColor: Color {
        if node.isCompleted { return Color(white: 0.3) }
        if isActive { return .white }
        return nodeColor
    }
    
    var textColor: Color {
        if node.isCompleted { return .gray }
        if isActive { return .white }
        return Color(white: 0.8)
    }
    
    var iconName: String {
        switch node.type {
        case .battle(let boss):
            return boss.style == .passive ? "figure.walk" : "bolt.fill"
        case .bonfire: 
            return "flame"
        case .treasure: 
            return "star"
        }
    }
    
    var title: String {
        switch node.type {
        case .battle(let boss): 
            return boss.name
        case .bonfire: 
            return "Rest"
        case .treasure: 
            return "Reward"
        }
    }
}

// MARK: - Supporting Views

/// 拖拽手柄组件
struct DragHandle: View {
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 20, height: 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }
}

/// 编辑按钮区域组件
struct EditActionsView: View {
    let node: TimelineNode
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ActionButton(
                icon: "pencil",
                color: .blue,
                action: onEdit
            )
            
            ActionButton(
                icon: "doc.on.doc",
                color: .green,
                action: onDuplicate
            )
            
            if !node.isCompleted && !node.isLocked {
                ActionButton(
                    icon: "trash",
                    color: .red,
                    action: onDelete
                )
            }
        }
        .padding(.horizontal, 12)
    }
}

/// 单个操作按钮组件
private struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.8))
                .clipShape(Circle())
        }
    }
}

// MARK: - Haptic Feedback Helper

private enum HapticFeedback {
    static func light() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            SwipeableTimelineNode(
                node: TimelineNode(
                    type: .battle(Boss(name: "Test Task", maxHp: 1800, category: .work)),
                    isLocked: false
                ),
                isEditMode: false
            )
        }
    }
}
