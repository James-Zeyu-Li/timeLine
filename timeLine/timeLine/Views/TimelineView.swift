import SwiftUI
import TimeLineCore

struct TimelineView: View {
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var stateManager: AppStateManager
    
    @State private var showRoutinePicker = false
    @State private var showingEditSheet = false
    @State private var templateToEdit: TaskTemplate?
    @State private var editingNodeId: UUID?
    @State private var isEditMode = false // 🎯 新增编辑模式状态
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 🎯 Priority 1: 明确的视觉断层（32pt breathing room）
                Color.clear.frame(height: 32)
                
                // Journey Section Label - 作为Playfield的入口标识
                HStack {
                    Text("YOUR JOURNEY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(.cyan.opacity(0.8))
                    Spacer()
                    
                    // 🎯 编辑模式切换按钮
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isEditMode.toggle()
                        }
                        
                        // 触觉反馈
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isEditMode ? "checkmark" : "slider.horizontal.3")
                                .font(.system(size: 12, weight: .bold))
                            Text(isEditMode ? "Done" : "Edit")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(isEditMode ? .green : .gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isEditMode ? Color.green.opacity(0.1) : Color(white: 0.1))
                        )
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 16)
                
                // Timeline Nodes with reorder support - 🎯 优化间距和交互
                ForEach(daySession.nodes) { node in
                    SwipeableTimelineNode(node: node)
                        .onTapGesture {
                            handleTap(on: node)
                        }
                        .padding(.bottom, 8) // 🎯 节点间增加间距
                }
                .onMove(perform: moveNodes)
                .onDelete(perform: deleteNodes)
                
                // Deck Bar Section - 🎯 明确的行动区域，包含Journey功能
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("ADD TO JOURNEY")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(.cyan.opacity(0.8))
                        Spacer()
                        Text("Tap cards to add tasks")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .padding(.horizontal, 40)
                    
                    // 🎯 添加Routine Packs按钮
                    HStack {
                        Button(action: { showRoutinePicker = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.cyan)
                                Text("ROUTINE PACKS")
                                    .font(.system(.caption, design: .rounded))
                                    .bold()
                                    .tracking(2)
                                    .foregroundColor(.cyan)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.cyan)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.cyan.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                    
                    DeckBar()
                        .environmentObject(templateStore)
                        .environmentObject(daySession)
                        .environmentObject(stateManager)
                        .padding(.leading, 24)
                }
                .padding(.vertical, 24)
                
                // Bottom spacing
                Color.clear.frame(height: 60)
            }
        }
        .safeAreaInset(edge: .top) {
            HeaderView(
                focusedMinutes: Int(engine.totalFocusedToday / 60),
                progress: daySession.completionProgress
            )
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $showRoutinePicker) {
            RoutinePickerView()
                .environmentObject(daySession)
                .environmentObject(stateManager)
        }
        .sheet(isPresented: $showingEditSheet) {
            TaskSheet(templateToEdit: $templateToEdit, isEditingNode: true) { updatedTemplate in
                if let id = editingNodeId {
                    daySession.updateNode(id: id, payload: updatedTemplate)
                    stateManager.requestSave()
                }
                editingNodeId = nil
                templateToEdit = nil
            }
        }
    }
    
    private func handleTap(on node: TimelineNode) {
        guard node.id == daySession.currentNode?.id, !node.isLocked, !node.isCompleted else { return }
        
        if case .battle(let boss) = node.type {
            engine.startBattle(boss: boss)
        } else if case .bonfire = node.type {
            engine.startRest()
        }
    }
    
    private func moveNodes(from source: IndexSet, to destination: Int) {
        daySession.moveNode(from: source, to: destination)
        stateManager.requestSave()
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func deleteNodes(at offsets: IndexSet) {
        for index in offsets {
            let node = daySession.nodes[index]
            if !node.isCompleted && !node.isLocked {
                daySession.deleteNode(id: node.id)
            }
        }
        stateManager.requestSave()
    }
    
    private func startEditing(node: TimelineNode) {
        if case .battle(let boss) = node.type {
            let temp = TaskTemplate(
                id: boss.id,
                title: boss.name,
                style: boss.style,
                duration: boss.maxHp,
                repeatRule: .none,
                category: boss.category
            )
            self.templateToEdit = temp
            self.editingNodeId = node.id
            self.showingEditSheet = true
        }
    }
}

// MARK: - Header View (Read-Only Status Bar)
struct HeaderView: View {
    let focusedMinutes: Int
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    // 🎯 移除Journey按钮，这个功能应该在DeckBar区域
                    HStack(spacing: 8) {
                        Text("Day")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        Text("1")
                            .font(.system(.largeTitle, design: .rounded))
                            .bold()
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Stats Chips (Read-Only) - 🎯 恢复MIN标签说明
                VStack(alignment: .center, spacing: 2) {
                    Text("\(focusedMinutes)")
                        .font(.system(.title2, design: .monospaced))
                        .bold()
                        .foregroundColor(.green)
                    Text("MIN")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.green.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TODAY'S PROGRESS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(white: 0.1))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(
                                colors: [.green, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * CGFloat(progress), height: 6)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            // 🎯 Priority 1: 更明确的分隔线
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .cyan.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
    }
}

// Stat Chip Component
struct StatChip: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .monospaced))
                .bold()
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1)
                .foregroundColor(color.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Timeline Node View
struct TimelineNodeView: View {
    let node: TimelineNode
    @EnvironmentObject var daySession: DaySession
    
    var isActive: Bool {
        return node.id == daySession.currentNode?.id
    }
    
    var body: some View {
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
            
            // Text Content - 🎯 Priority 3: 信息密度优化
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(isActive ? .bold : .semibold)
                    .foregroundColor(textColor)
                    .strikethrough(node.isCompleted)
                
                // 🎯 只有活跃节点显示完整信息
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
                    // 🎯 锁定节点只显示轮廓提示
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
        .padding(.horizontal, 40)
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
        .opacity(node.isLocked ? 0.3 : 1.0) // 🎯 更强的视觉弱化
    }
    
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

// Tag Badge Component
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
