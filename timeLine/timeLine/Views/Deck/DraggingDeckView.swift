import SwiftUI

struct DraggingDeckView: View {
    let deckId: UUID
    
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    var body: some View {
        if let deck = deckStore.get(id: deckId) {
            VStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text(deck.title)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("\(deck.count) cards")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(12)
            .frame(width: 120, height: 140)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                    )
            )
            .shadow(color: .cyan.opacity(0.3), radius: 12, x: 0, y: 6)
            .position(
                x: dragCoordinator.dragLocation.x + (dragCoordinator.activePayload?.initialOffset.width ?? 0),
                y: dragCoordinator.dragLocation.y + (dragCoordinator.activePayload?.initialOffset.height ?? 0)
            )
            .animation(.interactiveSpring(), value: dragCoordinator.dragLocation)
        }
    }
}
