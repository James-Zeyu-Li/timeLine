import SwiftUI
import TimeLineCore

struct TimelineNodeRow: View {
    let node: TimelineNode
    let index: Int
    let isSelected: Bool
    let isCurrent: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let timeInfo: MapTimeInfo?
    
    var body: some View {
        VStack(spacing: 0) {
            // Main timeline row
            HStack(spacing: 12) {
                // Timeline connector
                VStack(spacing: 0) {
                    if index > 0 {
                        Rectangle()
                            .fill(Color(red: 0.8, green: 0.75, blue: 0.7))
                            .frame(width: 2, height: 20)
                    }
                    
                    // Node indicator
                    Circle()
                        .fill(nodeColor)
                        .frame(width: nodeSize, height: nodeSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .overlay(
                            nodeIcon
                        )
                    
                    if index < 10 { // Assume max 10 nodes for demo
                        Rectangle()
                            .fill(Color(red: 0.8, green: 0.75, blue: 0.7))
                            .frame(width: 2, height: 20)
                    }
                }
                
                // Task info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(nodeTitle)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(isSelected ? .bold : .medium)
                                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.1))
                            
                            HStack(spacing: 8) {
                                Text(nodeSubtitle)
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                                
                                if let timeInfo = timeInfo {
                                    Text("• \(timeInfo.displayText)")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Status indicator
                        statusIndicator
                    }
                    
                    // Expanded current task details
                    if isCurrent {
                        currentTaskDetails
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: isCurrent ? 16 : 8)
                    .fill(isCurrent ? Color.white : (isSelected ? Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.1) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: isCurrent ? 16 : 8)
                            .stroke(isCurrent ? Color(red: 1.0, green: 0.6, blue: 0.2) : (isSelected ? Color(red: 1.0, green: 0.6, blue: 0.2) : Color.clear), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(isCurrent ? 0.1 : 0), radius: isCurrent ? 8 : 0, x: 0, y: isCurrent ? 4 : 0)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
    }
    
    private var nodeColor: Color {
        if node.isCompleted {
            return Color(red: 0.3, green: 0.8, blue: 0.7)
        } else if isCurrent {
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        } else {
            return Color(red: 0.8, green: 0.75, blue: 0.7)
        }
    }
    
    private var nodeSize: CGFloat {
        isCurrent ? 24 : 20
    }
    
    private var statusIndicator: some View {
        Group {
            if node.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.7))
            } else if isCurrent {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2))
                }
            } else {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2))
            }
        }
    }
    
    @ViewBuilder
    private var currentTaskDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(Color(red: 0.9, green: 0.85, blue: 0.8))
            
            // Task description
            Text(taskDescription)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.3))
                .lineLimit(2)
            
            // Time and action
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME REMAINING")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                    
                    Text(timeRemaining)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.1))
                }
                
                Spacer()
                
                Button(action: onTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(actionButtonText)
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 1.0, green: 0.6, blue: 0.2))
                    )
                }
            }
        }
        .padding(.top, 8)
    }
    
    private var taskDescription: String {
        switch node.type {
        case .battle(_):
            return "Focus on the core mechanics. Avoid side quests (social media)."
        case .bonfire:
            return "Take a well-deserved break to recharge your energy."
        case .treasure:
            return "Collect your bonus reward for completing tasks."
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
    
    private var actionButtonText: String {
        if node.isCompleted {
            return "Complete"
        } else {
            return "Start"
        }
    }
    
    private var nodeIcon: some View {
        Group {
            switch node.type {
            case .battle:
                Image(systemName: "person.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            case .bonfire:
                Image(systemName: "flame.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            case .treasure:
                Image(systemName: "star.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var nodeTitle: String {
        switch node.type {
        case .battle(let boss):
            return boss.name
        case .bonfire:
            return "Rest Point"
        case .treasure:
            return "Treasure"
        }
    }
    
    private var nodeSubtitle: String {
        switch node.type {
        case .battle(let boss):
            let minutes = Int(boss.maxHp / 60)
            return node.isCompleted ? "Completed • \(minutes)m" : "Future Quest • \(minutes)m"
        case .bonfire(let duration):
            let minutes = Int(duration / 60)
            return "Rest • \(minutes)m"
        case .treasure:
            return "Bonus"
        }
    }
    
    private var isActive: Bool {
        isCurrent
    }
}