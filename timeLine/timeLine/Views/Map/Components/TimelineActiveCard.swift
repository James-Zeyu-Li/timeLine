import SwiftUI
import TimeLineCore

struct TimelineActiveCard: View {
    let presenter: TimelineNodePresenter
    let onTap: () -> Void
    let onEdit: () -> Void
    let onMenuFrameChange: (CGRect) -> Void
    var namespace: Namespace.ID
    var nodeId: UUID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    ZStack {
                        Circle()
                            .fill(PixelTheme.secondary.opacity(0.12))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(PixelTheme.secondary.opacity(0.35), lineWidth: 1)
                            )
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(PixelTheme.secondary)
                    }
                }
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .background(
                    GeometryReader { proxy in
                        Color.clear
                        .onAppear { onMenuFrameChange(proxy.frame(in: .global)) }
                            .onChange(of: proxy.frame(in: .global)) { _, newFrame in
                                onMenuFrameChange(newFrame)
                            }
                    }
                )
                .buttonStyle(.plain)
            }
            
            // Task Title
            Text(presenter.nodeTitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(PixelTheme.textPrimary)
                .lineLimit(2)
                .padding(.top, 6)
            
            // Task Description
            Text(presenter.taskDescription)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(PixelTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            
            // Time and Action Section
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME REMAINING")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(PixelTheme.textSecondary)
                        .tracking(0.6)
                    
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
            .padding(.top, 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(minHeight: 220, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PixelTheme.cardBackground)
                .stroke(PixelTheme.primary, lineWidth: 2)
        )
        // Outer padding keeps the card aligned with the list column
        .padding(.horizontal, 16)
        // Applied negative top padding to raise the card closer to the next task
        .padding(.top, 0)
        .padding(.bottom, 12)
        // Ensure content shape is solid
        .contentShape(Rectangle())
    }
}
