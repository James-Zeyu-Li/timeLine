import SwiftUI
import TimeLineCore

struct GhostNodeView: View {
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var dragDropCoordinator: DragDropCoordinator
    
    // Optional: Pass height explicitly if known, otherwise calculate
    var expectedHeight: CGFloat = 80
    
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PixelTheme.background.opacity(0.5))
            
            // Dashed Glowing Border
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 8])
                )
                .foregroundColor(PixelTheme.primary.opacity(0.6))
                .shadow(color: PixelTheme.primary.opacity(0.4), radius: pulse ? 8 : 4)
            
            // Icon
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(PixelTheme.primary.opacity(0.5))
        }
        .frame(height: expectedHeight)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
