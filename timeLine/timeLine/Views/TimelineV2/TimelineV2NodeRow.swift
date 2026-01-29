import SwiftUI
import TimeLineCore

struct TimelineV2NodeRow: View {
    let task: TimelineTask
    let onToggle: () -> Void
    
    // Internal State mimicking V1 interaction
    @State private var isPressing = false
    
    // V1 UI Constants/Presenters logic inline for simplicity since V1 Presenter is coupled to Node
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // MARK: - Left Axis
            ZStack {
                // Timeline Line
                TimelinePathLine(isCompleted: task.status == .done, isCurrent: false)
                    .frame(width: 40)
                    .frame(maxHeight: .infinity)
                
                VStack(spacing: 4) {
                    // Node Icon (Simplified)
                    ZStack {
                        Circle()
                            .fill(iconBackgroundColor)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundColor(iconForegroundColor)
                    }
                    
                    // Time Marker
                    Text(timeLabel)
                        .font(.custom("PixelCode", size: 10))
                        .foregroundColor(PixelTheme.textSecondary)
                }
                .padding(.top, 12)
            }
            .frame(width: 50)
            
            // MARK: - Card Content
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(task.title)
                            .font(.custom("PixelCode", size: 14))
                            .foregroundColor(task.status == .done ? PixelTheme.textSecondary : PixelTheme.textPrimary)
                            .strikethrough(task.status == .done)
                            .lineLimit(2)
                        
                        Spacer()
                    }
                    
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(.custom("PixelCode", size: 10))
                            .foregroundColor(PixelTheme.textSecondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(task.status == .done ? PixelTheme.surface.opacity(0.5) : PixelTheme.surface)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(PixelTheme.primary.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(CardButtonStyle()) // Helper from V1
        }
        .contentShape(Rectangle())
        .scaleEffect(isPressing ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPressing)
    }
    
    // MARK: - Helpers (Mimicking Presenter)
    
    var iconName: String {
        switch task.status {
        case .done: return "checkmark"
        case .todo: return "person.fill" // Default icon
        }
    }
    
    var iconBackgroundColor: Color {
        if task.status == .done {
            return PixelTheme.secondary // Brown/Wood
        } else {
            return PixelTheme.textSecondary.opacity(0.2) // Grey
        }
    }
    
    var iconForegroundColor: Color {
        if task.status == .done {
            return .white
        } else {
            return PixelTheme.textSecondary
        }
    }
    
    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: task.createdAt)
    }
    
    var subtitleText: String? {
        if let completedAt = task.completedAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Completed at \(formatter.string(from: completedAt))"
        }
        return nil
    }
}

// Needed V1 Components if not global
// TimelinePathLine
// PixelTheme
// CardButtonStyle
