import SwiftUI
import TimeLineCore

// MARK: - Path Line
struct TimelinePathLine: View {
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
                        // If completed, draw full way to connect to next
                        let endY = isCurrent ? proxy.size.height / 2 : proxy.size.height
                        path.addLine(to: CGPoint(x: proxy.size.width / 2, y: endY))
                    }
                    .stroke(PixelTheme.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
            }
            .opacity(1.0) // Force full opacity for the line
        }
    }
}

// MARK: - Time Marker
struct TimelineTimeMarker: View {
    let isCurrent: Bool
    let estimatedTimeInfo: String?
    let isCompleted: Bool
    
    var body: some View {
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
                    .multilineTextAlignment(.center)
                    .foregroundColor(isCompleted ? PixelTheme.textSecondary : PixelTheme.textSecondary.opacity(0.8))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(PixelTheme.cardBackground.opacity(0.8))
                    )
            }
        }
    }
}

// MARK: - Node Icon
struct TimelineNodeIconView: View {
    let iconName: String
    let iconSize: CGFloat
    let iconImageSize: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    
    var body: some View {
        ZStack {
            // Shadow for depth
            Circle()
                .fill(Color.black.opacity(0.15))
                .frame(width: iconSize + 4, height: iconSize + 4)
                .offset(y: 2)
            
            // Background circle with border
            Circle()
                .fill(backgroundColor)
                .frame(width: iconSize, height: iconSize)
                .overlay(
                    Circle()
                        .stroke(PixelTheme.primary.opacity(0.1), lineWidth: 1)
                )
            
            // Icon
            Image(systemName: iconName)
                .font(.system(size: iconImageSize, weight: .bold))
                .foregroundColor(foregroundColor)
        }
    }
}


