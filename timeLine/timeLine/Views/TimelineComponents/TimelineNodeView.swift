import SwiftUI
import TimeLineCore

// MARK: - Node View
struct TimelineNodeView: View {
    let node: TimelineNode
    var isEditMode: Bool = false
    var isHero: Bool = false
    var isActive: Bool
    var isLocked: Bool
    var onDragChanged: ((DragGesture.Value) -> Void)?
    var onDragEnded: ((DragGesture.Value) -> Void)?
    
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    
    var body: some View {
        HStack(spacing: isHero ? 24 : 20) {
            if isEditMode {
                Button(role: .destructive) {
                    daySession.deleteNode(id: node.id)
                    stateManager.requestSave()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
            
            // Node Icon
            ZStack {
                // Glow effect for Hero node
                if isHero && !node.isCompleted {
                    Circle()
                        .fill(RadialGradient(
                            colors: [nodeColor.opacity(0.6), nodeColor.opacity(0.3), nodeColor.opacity(0)], 
                            center: .center, 
                            startRadius: 0, 
                            endRadius: 60
                        ))
                        .frame(width: 120, height: 120)
                        .blur(radius: 8)
                }
                
                Circle().fill(Color.black).frame(width: isHero ? 70 : 58, height: isHero ? 70 : 58)
                Circle().fill(nodeBackgroundColor).frame(width: isHero ? 60 : 50, height: isHero ? 60 : 50)
                    .overlay(Circle().stroke(borderColor, lineWidth: isHero ? 4 : 2))
                
                Image(systemName: iconName)
                    .font(.system(size: isHero ? 28 : 20, weight: isActive ? .bold : .regular))
                    .foregroundColor(iconColor)
            }
            .animation(.easeInOut(duration: 0.3), value: isHero)
            
            VStack(alignment: .leading, spacing: isHero ? 8 : 6) {
                Text(title)
                    .font(.system(isHero ? .title3 : .headline, design: .rounded))
                    .fontWeight(isHero ? .bold : .semibold)
                    .foregroundColor(textColor)
                
                // Always show duration badge for all tasks
                HStack(spacing: 8) {
                    TagBadge(
                        icon: durationIcon,
                        text: durationText,
                        color: durationColor
                    )
                    if case .battle(let boss) = node.type {
                        CategoryBadge(category: boss.category)
                    }
                }
                
                if isLocked {
                    Text("Locked").font(.caption2).foregroundColor(.gray.opacity(0.6))
                }
            }
            
            Spacer()
            
            if isEditMode {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.gray)
                    .font(.title3)
                    .frame(width: 44, height: 44)
            } else {
                if node.isCompleted {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                } else if isLocked {
                    Image(systemName: "lock.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(isActive ? Color.white.opacity(0.05) : Color.clear)
        .opacity(isLocked ? 0.3 : 1.0)
        // Make entire row draggable in Edit Mode
        .contentShape(Rectangle()) // Ensure hit test works on clear background
        .gesture(
            isEditMode ? 
            DragGesture(minimumDistance: 0, coordinateSpace: .named("scroll"))
                .onChanged { value in onDragChanged?(value) }
                .onEnded { value in onDragEnded?(value) }
            : nil
        )
    }
    
    var nodeColor: Color {
        switch node.type {
        case .battle(let boss): return boss.style == .passive ? .blue : .red
        case .bonfire: return .orange
        case .treasure: return .yellow
        }
    }
    var nodeBackgroundColor: Color { node.isCompleted ? Color(white: 0.1) : Color.black }
    // Border: Hero gets brighter color
    var borderColor: Color { 
        if isHero { 
            return isActive ? .white : nodeColor.opacity(0.8)  // Brighter border for Hero
        }
        return node.isCompleted ? Color(white: 0.3) : nodeColor.opacity(0.5)
    }
    var iconColor: Color { (node.isCompleted || !isActive) ? nodeColor.opacity(0.6) : .white }
    var textColor: Color { node.isCompleted ? .gray : (isActive ? .white : Color(white: 0.8)) }
    var iconName: String {
        switch node.type {
        case .battle(let boss): return boss.style == .passive ? "figure.walk" : "bolt.fill"
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
    // Duration display for all tasks
    var durationMinutes: Int {
        switch node.type {
        case .battle(let boss):
            return max(1, Int(boss.maxHp / 60))
        case .bonfire(let dur):
            return max(1, Int(dur / 60))
        case .treasure:
            return 0
        }
    }
    var durationText: String { "\(durationMinutes) min" }
    var durationIcon: String { "clock.fill" }
    var durationColor: Color {
        switch node.type {
        case .battle(let boss):
            return boss.style == .passive ? .cyan : .orange
        case .bonfire:
            return .orange
        case .treasure:
            return .yellow
        }
    }
}

struct TagBadge: View {
    let icon: String
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(.system(.caption2, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.15)).cornerRadius(6)
    }
}

struct CategoryBadge: View {
    let category: TaskCategory
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon).font(.system(size: 9))
            Text(category.rawValue.uppercased()).font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(.gray)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Color(white: 0.15)).cornerRadius(4)
    }
}
