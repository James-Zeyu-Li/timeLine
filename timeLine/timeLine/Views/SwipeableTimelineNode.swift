import SwiftUI
import TimeLineCore

// MARK: - 可滑动和拖拽的Timeline节点
struct SwipeableTimelineNode: View {
    let node: TimelineNode
    let isEditMode: Bool // 🎯 新增编辑模式参数
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var engine: BattleEngine
    
    @State private var dragOffset: CGSize = .zero
    @State private var showingEditActions = false
    @State private var showingEditSheet = false
    @State private var templateToEdit: TaskTemplate?
    
    var isActive: Bool {
        return node.id == daySession.currentNode?.id
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 🎯 拖拽手柄（三道杠）- 编辑模式时更明显
            DragHandle()
                .opacity(isEditMode ? 1.0 : (showingEditActions ? 1.0 : 0.4))
                .animation(.easeInOut(duration: 0.2), value: showingEditActions)
                .animation(.easeInOut(duration: 0.2), value: isEditMode)
            
            // 主要内容区域
            HStack(spacing: 20) {
                // Node Icon
                ZStack {
                    if isActive {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [nodeColor.opacity(0.4), nodeColor.opacity(0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                    }
                    
                    Circle()
                        .fill(Color.black)
                        .frame(width: 58, height: 58)
                    
                    Circle()
                        .fill(nodeBackgroundColor)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(borderColor, lineWidth: isActive ? 3 : 2)
                        )
                        .shadow(color: isActive ? nodeColor.opacity(0.5) : .clear, radius: 8)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: isActive ? .bold : .regular))
                        .foregroundColor(iconColor)
                        .scaleEffect(isActive ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: isActive)
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(isActive ? .bold : .semibold)
                        .foregroundColor(textColor)
                        .strikethrough(node.isCompleted)
                    
                    // 信息密度优化
                    if isActive || node.isCompleted {
                        HStack(spacing: 8) {
                            if case .battle(let boss) = node.type {
                                if boss.style == .passive {
                                    TagBadge(icon: "checkmark.circle.fill", text: "Passive Task", color: .cyan)
                                } else {
                                    TagBadge(icon: "clock.fill", text: "\(Int(boss.maxHp / 60)) min", color: .orange)
                                }
                                
                                // Category badge
                                HStack(spacing: 4) {
                                    Image(systemName: boss.category.icon)
                                        .font(.system(size: 9))
                                    Text(boss.category.rawValue.uppercased())
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
                    } else if node.isLocked {
                        Text("Locked")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Status Indicator
                if node.isCompleted {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                    }
                } else if node.isLocked {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                isActive ?
                    LinearGradient(
                        colors: [nodeColor.opacity(0.05), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
            )
            .opacity(node.isLocked ? 0.3 : 1.0)
            
            // 🎯 右侧编辑按钮区域（滑动时显示或编辑模式时显示）
            if showingEditActions || isEditMode {
                EditActionsView(
                    node: node,
                    onEdit: { startEditing() },
                    onDuplicate: { duplicateNode() },
                    onDelete: { deleteNode() }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .offset(x: dragOffset.width)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // 只允许向左滑动
                    if value.translation.x < 0 {
                        dragOffset = CGSize(width: max(value.translation.x, -120), height: 0)
                        
                        // 当滑动超过一定距离时显示编辑按钮
                        if dragOffset.width < -60 && !showingEditActions {
                            withAnimation(.spring(response: 0.3)) {
                                showingEditActions = true
                            }
                            
                            // 触觉反馈
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.4)) {
                        if dragOffset.width < -60 {
                            // 保持展开状态
                            dragOffset = CGSize(width: -120, height: 0)
                            showingEditActions = true
                        } else {
                            // 回弹到原位
                            dragOffset = .zero
                            showingEditActions = false
                        }
                    }
                }
        )
        .onTapGesture {
            if showingEditActions {
                // 如果编辑按钮显示中，点击收起
                withAnimation(.spring(response: 0.4)) {
                    dragOffset = .zero
                    showingEditActions = false
                }
            } else {
                // 正常的点击处理
                handleTap()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TaskSheet(templateToEdit: $templateToEdit, isEditingNode: true) { updatedTemplate in
                daySession.updateNode(id: node.id, payload: updatedTemplate)
                stateManager.requestSave()
                templateToEdit = nil
            }
        }
    }
    
    // MARK: - Actions
    private func handleTap() {
        guard node.id == daySession.currentNode?.id, !node.isLocked, !node.isCompleted else { return }
        
        if case .battle(let boss) = node.type {
            engine.startBattle(boss: boss)
        } else if case .bonfire = node.type {
            engine.startRest()
        }
    }
    
    private func startEditing() {
        if case .battle(let boss) = node.type {
            let temp = TaskTemplate(
                id: boss.id,
                title: boss.name,
                style: boss.style,
                duration: boss.maxHp,
                repeatRule: .none,
                category: boss.category
            )
            templateToEdit = temp
            showingEditSheet = true
        }
        
        // 收起编辑按钮
        withAnimation(.spring(response: 0.4)) {
            dragOffset = .zero
            showingEditActions = false
        }
    }
    
    private func duplicateNode() {
        daySession.duplicateNode(id: node.id)
        stateManager.requestSave()
        
        // 收起编辑按钮
        withAnimation(.spring(response: 0.4)) {
            dragOffset = .zero
            showingEditActions = false
        }
    }
    
    private func deleteNode() {
        if !node.isCompleted && !node.isLocked {
            daySession.deleteNode(id: node.id)
            stateManager.requestSave()
        }
        
        // 收起编辑按钮
        withAnimation(.spring(response: 0.4)) {
            dragOffset = .zero
            showingEditActions = false
        }
    }
    
    // MARK: - Computed Properties
    var nodeColor: Color {
        switch node.type {
        case .battle(let boss):
            return boss.style == .passive ? .blue : .red
        case .bonfire: return .orange
        case .treasure: return .yellow
        }
    }
    
    var nodeBackgroundColor: Color {
        if node.isCompleted { return Color(white: 0.1) }
        return Color.black
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
        case .bonfire: return "flame"
        case .treasure: return "star"
        }
    }
    
    var title: String {
        switch node.type {
        case .battle(let boss): return boss.name
        case .bonfire: return "Rest"
        case .treasure: return "Reward"
        }
    }
}

// MARK: - 拖拽手柄组件
struct DragHandle: View {
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 20, height: 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }
}

// MARK: - 编辑按钮区域
struct EditActionsView: View {
    let node: TimelineNode
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // 编辑按钮
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.8))
                    .clipShape(Circle())
            }
            
            // 复制按钮
            Button(action: onDuplicate) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.green.opacity(0.8))
                    .clipShape(Circle())
            }
            
            // 删除按钮（只有未完成且未锁定的任务才显示）
            if !node.isCompleted && !node.isLocked {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Tag Badge Component (复用)
struct TagBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(text)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            SwipeableTimelineNode(
                node: TimelineNode(
                    type: .battle(Boss(name: "Test Task", maxHp: 1800, category: .work)),
                    isLocked: false
                )
            )
        }
    }
}