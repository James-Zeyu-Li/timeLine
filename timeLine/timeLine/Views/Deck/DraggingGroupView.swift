import SwiftUI
import TimeLineCore

struct DraggingGroupView: View {
    let memberTemplateIds: [UUID]
    
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    private var templates: [CardTemplate] {
        memberTemplateIds.compactMap { cardStore.get(id: $0) }
    }
    
    var body: some View {
        if let first = templates.first {
            CardView(template: first)
                .overlay(alignment: .topTrailing) {
                    groupBadge
                }
                .scaleEffect(1.12)
                .shadow(color: .purple.opacity(0.5), radius: 20, x: 0, y: 10)
                .position(
                    x: dragCoordinator.dragLocation.x + (dragCoordinator.activePayload?.initialOffset.width ?? 0),
                    y: dragCoordinator.dragLocation.y + (dragCoordinator.activePayload?.initialOffset.height ?? 0)
                )
                .animation(.interactiveSpring(), value: dragCoordinator.dragLocation)
        } else {
            Text("Group (\(memberTemplateIds.count))")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .position(
                    x: dragCoordinator.dragLocation.x + (dragCoordinator.activePayload?.initialOffset.width ?? 0),
                    y: dragCoordinator.dragLocation.y + (dragCoordinator.activePayload?.initialOffset.height ?? 0)
                )
                .animation(.interactiveSpring(), value: dragCoordinator.dragLocation)
        }
    }
    
    private var groupBadge: some View {
        Text("\(templates.count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(6)
            .background(
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .offset(x: 6, y: -6)
    }
}
