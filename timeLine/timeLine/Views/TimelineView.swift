import SwiftUI
import TimeLineCore

struct TimelineView: View {
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var templateStore: TemplateStore
    
    @State private var showRoutinePicker = false
    @State private var showingEditSheet = false
    @State private var templateToEdit: TaskTemplate? // Using Template struct as DTO for editing
    
    // Binding to update the actual node after editing
    @State private var editingNodeId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Header
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: { showRoutinePicker = true }) {
                            HStack {
                                Text("JOURNEY")
                                    .font(.system(.caption, design: .rounded))
                                    .bold()
                                    .tracking(2)
                                    .foregroundColor(.gray)
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Text("Day 1")
                            .font(.system(.largeTitle, design: .rounded))
                            .bold()
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(engine.totalFocusedToday / 60))m")
                            .font(.system(.title2, design: .monospaced))
                            .bold()
                            .foregroundColor(.green)
                        Text("FOCUSED")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.gray)
                    }
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(white: 0.15))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Color.green)
                            .frame(width: geo.size.width * CGFloat(daySession.completionProgress), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(24)
            .background(Color.black)
            
            // Map List
            ScrollView {
                ZStack {
                    // Central Connecting Line
                    if !daySession.nodes.isEmpty {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color(white: 0.15))
                                .frame(width: 2)
                                .position(x: 40 + 25, y: geo.size.height / 2) // aligned with icon center
                        }
                    }
                    
                    VStack(spacing: 0) {
                        ForEach(daySession.nodes) { node in
                            TimelineNodeView(node: node)
                                .onTapGesture {
                                    handleTap(on: node)
                                }
                                .contextMenu {
                                    Button {
                                        startEditing(node: node)
                                    } label: {
                                        Label("Edit Task", systemImage: "pencil")
                                    }
                                    
                                    if !node.isCompleted && !node.isLocked {
                                        Button(role: .destructive) {
                                            // Optional: Delete/Remove logic if needed
                                            // For V1, maybe just "Skip" force complete?
                                            // engine.forceCompleteTask() // This works only for current boss
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                        
                        // Deck Bar - The new "Next Challenge" area
                        VStack(alignment: .leading, spacing: 12) {
                            Text("NEXT CHALLENGE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 40)
                            
                            // Horizontal Deck
                            DeckBar()
                                .environmentObject(templateStore) // Pass Store
                                .environmentObject(daySession)    // Pass Session
                                .padding(.leading, 24) // Align with design
                        }
                        .padding(.vertical, 20)
                        
                        // Extra spacing at bottom
                        Color.clear.frame(height: 60)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $showRoutinePicker) {
            RoutinePickerView()
                .environmentObject(daySession)
        }
        .sheet(isPresented: $showingEditSheet) {
            TaskSheet(templateToEdit: $templateToEdit, isEditingNode: true) { updatedTemplate in
                // Save Back to Node
                guard let id = editingNodeId, let index = daySession.nodes.firstIndex(where: { $0.id == id }) else { return }
                
                if case .battle(var boss) = daySession.nodes[index].type {
                    boss.name = updatedTemplate.title
                    boss.style = updatedTemplate.style
                    if let duration = updatedTemplate.duration {
                        boss.maxHp = duration
                        // Reset current HP if not started? Or scale?
                        // For simplicity, reset current HP if max changed significantly or just set max.
                        if boss.currentHp > duration { boss.currentHp = duration }
                    }
                    // Update Node
                    daySession.nodes[index].type = .battle(boss)
                }
                
                // Reset
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
    private func startEditing(node: TimelineNode) {
        if case .battle(let boss) = node.type {
            // Convert Boss -> Temporary Template for Editing
            let temp = TaskTemplate(
                id: boss.id, 
                title: boss.name,
                style: boss.style,
                duration: boss.maxHp,
                repeatRule: .none, // Nodes don't repeat themselves, templates do
                category: .work 
            )
            
            self.templateToEdit = temp
            self.editingNodeId = node.id
            self.showingEditSheet = true
        }
    }
}

// Minimal Chip View
struct TagChip: View {
    let text: String
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.3))
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.5), lineWidth: 1))
        }
    }
}

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
                // Background Mask
                Circle()
                    .fill(Color.black)
                    .frame(width: 58, height: 58)
                
                if isActive {
                    Circle()
                        .fill(nodeColor.opacity(0.3))
                        .frame(width: 64, height: 64)
                        .blur(radius: 8)
                }
                
                Circle()
                    .stroke(borderColor, lineWidth: isActive ? 3 : 2)
                    .background(Circle().fill(nodeBackgroundColor))
                    .frame(width: 50, height: 50)
                
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            // Text Info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(textColor)
                    .strikethrough(node.isCompleted)
                
                if case .battle(let boss) = node.type {
                    if boss.style == .passive {
                         Text("Passive Task")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.blue)
                    } else {
                        Text("\(Int(boss.maxHp / 60)) min")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Status Icon for Completed
            if node.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(white: 0.3))
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
        .opacity(node.isLocked ? 0.4 : 1.0)
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
