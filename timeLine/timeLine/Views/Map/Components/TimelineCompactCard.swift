import SwiftUI
import TimeLineCore

struct TimelineCompactCard: View {
    let presenter: TimelineNodePresenter
    let node: TimelineNode
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(presenter.nodeTitle)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(node.isCompleted ? PixelTheme.textSecondary : presenter.compactTaskTextColor)
                    .strikethrough(node.isCompleted)
                    .lineLimit(1)
                
                Text(presenter.compactSubtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(presenter.compactTaskSecondaryTextColor)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Right side info
            if node.isCompleted {
                Text(presenter.compactSubtitle)
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(PixelTheme.success.opacity(presenter.compactTaskOpacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PixelTheme.cardBackground.opacity(presenter.compactTaskOpacity))
        )
        // REMOVED Tap Gesture for compact/future nodes to force sequential progression
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
    }
}
