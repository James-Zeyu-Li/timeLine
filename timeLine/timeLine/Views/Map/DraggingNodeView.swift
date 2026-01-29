import SwiftUI
import TimeLineCore

struct DraggingNodeView: View {
    let nodeId: UUID
    
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    @EnvironmentObject var engine: BattleEngine
    
    var body: some View {
        if let node = daySession.nodes.first(where: { $0.id == nodeId }) {
            // We use a simplified view that looks like the CompactTaskCard
            // This avoids all the complexity of TimelineNodeRow actions/state
            // Since we are dragging, we don't need buttons or interactivity
            
            HStack(alignment: .top, spacing: 0) {
                // Approximate width of the left axis column (50) + padding
                // But since we are dragging the *content*, usually the user expects the whole row?
                // Or just the card part?
                // The TimelineNodeRow includes the axis.
                // Let's replicate the Card part mostly, or the whole Row?
                // If we replicate the whole Row, the axis might look weird floating.
                // But keeping context is good.
                // Let's show the Card part only, as that's what physically feels draggable?
                // No, usually you drag the whole "Row".
                // Let's try to mimic the Compact Card.
                
                SimulatedCompactCard(node: node)
            }
            .frame(width: 300) // Fixed width or determined by geometry?
            // Ideally should match original width. 
            // Since we don't have the original proxy size here easily without passing it...
            // We will let it size itself or provide a reasonable default.
            .scaleEffect(1.05)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 10)
            // 拖拽预览以手指为中心，避免整张卡在手指下方挡住放置区域（符合 updatedUI 的 follow finger）
            .position(x: dragCoordinator.dragLocation.x, y: dragCoordinator.dragLocation.y)
        }
    }
}

private struct SimulatedCompactCard: View {
    let node: TimelineNode
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(PixelTheme.textPrimary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(PixelTheme.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PixelTheme.cardBackground)
        )
        .padding(.horizontal, 16)
    }
    
    private var title: String {
        switch node.type {
        case .battle(let boss): return boss.name
        case .bonfire: return "Break"
        case .treasure: return "Field Note"
        }
    }
    
    private var subtitle: String {
        switch node.type {
        case .battle(let boss): return "\(Int(boss.maxHp / 60))m"
        case .bonfire(let duration): return "\(Int(duration / 60))m"
        case .treasure: return "Note"
        }
    }
}
