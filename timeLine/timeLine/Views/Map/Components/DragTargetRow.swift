import SwiftUI
import TimeLineCore

struct DragTargetRow: View {
    let isActive: Bool
    
    var body: some View {
        // Only show if active (and implicitly dragging based on parent logic)
        if isActive {
             GhostNodeView()
                .transition(.scale)
        } else {
            Color.clear.frame(height: 0)
        }
    }
}
