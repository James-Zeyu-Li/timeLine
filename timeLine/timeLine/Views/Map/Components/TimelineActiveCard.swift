import SwiftUI
import TimeLineCore

struct TimelineActiveCard: View {
    let presenter: TimelineNodePresenter
    let onTap: () -> Void
    let onEdit: () -> Void
    var namespace: Namespace.ID
    var nodeId: UUID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // IN PROGRESS Label
            HStack {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(PixelTheme.primary)
                
                Text(presenter.currentTaskStatusText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(PixelTheme.primary)
                    .tracking(0.5)
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PixelTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // Task Title
            Text(presenter.nodeTitle)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(PixelTheme.textPrimary)
                .lineLimit(2)
            
            // Task Description
            Text(presenter.taskDescription)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(PixelTheme.textSecondary)
                .lineLimit(3)
            
            // Time and Action Section
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME REMAINING")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(PixelTheme.textSecondary)
                        .tracking(0.5)
                    
                    Text(presenter.timeRemaining)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(PixelTheme.textPrimary)
                }
                
                Spacer()
                
                // Play Button - Pure Tap Gesture
                ZStack {
                    Circle()
                        .fill(PixelTheme.primary)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 2) // Slight offset for visual balance
                }
                .contentShape(Circle())
                .matchedGeometryEffect(id: "playButton-\(nodeId)", in: namespace)
                // Gesture removed/ignored here as it is blocked.
                // It serves as the layout anchor.
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PixelTheme.cardBackground)
                .stroke(PixelTheme.primary, lineWidth: 2)
        )
        // Reduced horizontal padding to 16 only
        .padding(.horizontal, 16)
        // Applied negative top padding to raise the card closer to the next task
        .padding(.top, 0)
        .padding(.bottom, 12)
        // Ensure content shape is solid
        .contentShape(Rectangle())
    }
}
