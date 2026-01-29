import SwiftUI
import TimeLineCore

struct TimelineNodePresenter {
    let node: TimelineNode
    let isCurrent: Bool
    let engine: BattleEngine
    let daySession: DaySession
    
    // MARK: - Text Properties
    
    var nodeTitle: String {
        switch node.type {
        case .battle(let boss):
            return boss.name
        case .bonfire:
            return "Break"
        case .treasure:
            return "Field Note"
        }
    }
    
    var compactSubtitle: String {
        switch node.type {
        case .battle(let boss):
            if node.isCompleted {
                return "Completed +15 pts"
            } else {
                let minutes = Int(boss.maxHp / 60)
                return "Upcoming Task • \(minutes)m"
            }
        case .bonfire(let duration):
            return "Break (+10 Energy) • \(Int(duration/60))m"
        case .treasure:
            return "Bonus Note"
        }
    }
    
    var taskDescription: String {
        switch node.type {
        case .battle:
            // Show actual progress data
            let focusedMinutes = Int(engine.totalFocusedToday / 60)
            let completedTasks = daySession.nodes.filter { node in
                guard node.isCompleted else { return false }
                if case .battle = node.type { return true }
                return false
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
            return "Take a short break. Recharge for the next task."
        case .treasure:
            return "Open to review your notes and continue."
        }
    }
    
    var timeRemaining: String {
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
    
    var currentTaskStatusText: String {
        return "CURRENT TASK"
    }
    
    // MARK: - Icon & Color Properties
    
    var iconName: String {
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
    
    var iconSize: CGFloat {
        isCurrent ? 32 : 24
    }
    
    var iconImageSize: CGFloat {
        isCurrent ? 16 : 12
    }
    
    var compactTaskOpacity: Double {
        isCurrent ? 1.0 : 0.7
    }
    
    var iconBackgroundColor: Color {
        if isCurrent {
            return PixelTheme.primary
        } else if node.isCompleted {
            return PixelTheme.secondary // Use Secondary (Brown/Wood) for completed
        } else {
            return PixelTheme.textSecondary.opacity(0.3 * compactTaskOpacity)
        }
    }
    
    var iconForegroundColor: Color {
        if isCurrent || node.isCompleted {
            return .white
        } else {
            return PixelTheme.textSecondary.opacity(compactTaskOpacity)
        }
    }
    
    var compactTaskTextColor: Color {
        PixelTheme.textPrimary.opacity(compactTaskOpacity)
    }
    
    var compactTaskSecondaryTextColor: Color {
        PixelTheme.textSecondary.opacity(compactTaskOpacity)
    }
}
