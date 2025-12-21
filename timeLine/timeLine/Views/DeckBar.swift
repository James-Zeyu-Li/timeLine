import SwiftUI
import TimeLineCore

struct DeckBar: View {
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var engine: BattleEngine // Access to engine to forceComplete or check state? 
    // Actually, spawning modifies DaySession nodes. engine just runs the CURRENT boss.
    // We need DaySession to add nodes.
    @EnvironmentObject var daySession: DaySession
    
    @State private var showingTaskSheet = false
    @State private var editingTemplate: TaskTemplate? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 1. Add Card Button
                Button(action: {
                    editingTemplate = nil
                    showingTaskSheet = true
                }) {
                    VStack {
                        Image(systemName: "plus")
                            .font(.title2)
                        Text("New Card")
                            .font(.caption)
                    }
                    .frame(width: 80, height: 100)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(white: 0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
                }
                .foregroundColor(.white) // Explicit White
                .buttonStyle(PlainButtonStyle()) // Remove default blue tint
                
                // 2. Templates
                ForEach(templateStore.templates) { template in
                    Button(action: {
                        spawnTask(from: template)
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: template.category.icon)
                                    .font(.caption)
                                Spacer()
                                // Mode Icon
                                if template.style == .focus {
                                    Image(systemName: "bolt.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                } else {
                                    Image(systemName: "alarm") // Scheduled/Passive
                                        .font(.caption2)
                                        .foregroundColor(.cyan)
                                }
                            }
                            
                            Spacer()
                            
                            Text(template.title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white) // High contrast
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            HStack {
                                Text(formatDuration(template.duration ?? 0))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color(white: 0.8)) // Brighter than secondary
                                
                                Spacer()
                                
                                // Repeat Badge
                                if template.repeatRule != .none {
                                    Text(repeatBadge(for: template.repeatRule))
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.3))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(10)
                        .frame(width: 100, height: 120) // Slightly larger for badge
                        .background(Color(white: 0.15))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle()) // Avoid flash
                    .contextMenu {
                        Button {
                            spawnTask(from: template)
                        } label: {
                            Label("Spawn", systemImage: "play.fill")
                        }
                        
                        Button {
                            editingTemplate = template
                            showingTaskSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            templateStore.delete(template)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showingTaskSheet) {
            TaskSheet(templateToEdit: $editingTemplate)
        }
    }
    
    func spawnTask(from template: TaskTemplate) {
        let boss = TemplateManager.spawn(from: template)
        // Add to DaySession
        // We need to append to nodes
        // BUT DaySession updates mostly from RouteGenerator? 
        // We can just append.
        var newNodes = daySession.nodes
        newNodes.append(TimelineNode(
            type: .battle(boss),
            isLocked: false // Unlocked by default if spawned manually?
        ))
        
        // Use replacingWithAnimation or just set
        withAnimation {
            daySession.nodes = newNodes
            // daySession.objectWillChange.send()
        }
        
        print("Spawned \(boss.name)")
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration / 60)
        if m >= 60 {
            return "\(m/60)h" // Compact: 1h instead of 1h 0m
        }
        return "\(m)m"
    }
    
    func repeatBadge(for rule: RepeatRule) -> String {
        switch rule {
        case .none: return ""
        case .daily: return "DAILY"
        case .weekly: return "WEEKLY"
        case .monthly: return "MONTHLY"
        }
    }
}
