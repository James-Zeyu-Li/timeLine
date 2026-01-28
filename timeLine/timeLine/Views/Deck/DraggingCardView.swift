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
                .rotation3DEffect(
                    .degrees(5),
                    axis: (x: 1, y: 0, z: 0)
                )
                .rotationEffect(
                    .degrees(Double(dragCoordinator.dragOffset.width) / 20.0),
                    anchor: .center
                )
                .shadow(
                    color: PixelTheme.primary.opacity(0.3),
                    radius: 20,
                    x: 0,
                    y: 20
                )
                .position(
                    x: dragCoordinator.dragLocation.x + (dragCoordinator.activePayload?.initialOffset.width ?? 0),
                    y: dragCoordinator.dragLocation.y + (dragCoordinator.activePayload?.initialOffset.height ?? 0)
                )
                .animation(.interactiveSpring(), value: dragCoordinator.dragLocation)
        }
    }
}
