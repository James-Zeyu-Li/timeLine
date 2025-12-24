import SwiftUI
import TimeLineCore

// MARK: - Dragging Card View

struct DraggingCardView: View {
    let cardId: UUID
    
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    var body: some View {
        if let template = cardStore.get(id: cardId) {
            CardView(template: template)
                .scaleEffect(1.15)
                .shadow(color: .purple.opacity(0.5), radius: 20, x: 0, y: 10)
                .position(dragCoordinator.dragLocation)
                .animation(.interactiveSpring(), value: dragCoordinator.dragLocation)
        }
    }
}
