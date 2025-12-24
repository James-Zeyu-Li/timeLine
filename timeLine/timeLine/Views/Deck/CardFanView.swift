import SwiftUI
import TimeLineCore

// MARK: - Card Fan View

struct CardFanView: View {
    let tab: DeckTab

    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    @State private var raisedCardId: UUID?
    
    var body: some View {
        let cards = cardStore.orderedTemplates()
        let count = cards.count
        
        VStack(spacing: 12) {
            if let preview = previewCard {
                CardPreviewPanel(template: preview)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            ZStack {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    CardView(template: card)
                        .offset(fanOffset(index: index, total: count))
                        .rotationEffect(fanRotation(index: index, total: count))
                        .scaleEffect(raisedCardId == card.id ? 1.1 : 1.0)
                        .zIndex(raisedCardId == card.id ? 100 : Double(index))
                        .gesture(cardGesture(for: card))
                        .onTapGesture {
                            guard !appMode.isDragging else { return }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                raisedCardId = raisedCardId == card.id ? nil : card.id
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            guard !appMode.isDragging else { return }
                            appMode.enterCardEdit(cardTemplateId: card.id)
                        }
                        .animation(.spring(response: 0.3), value: raisedCardId)
                }
            }
            .frame(height: 200)
        }
    }
    
    // MARK: - Fan Layout
    
    private func fanOffset(index: Int, total: Int) -> CGSize {
        guard total > 1 else { return .zero }
        let centerIndex = Double(total - 1) / 2.0
        let offset = Double(index) - centerIndex
        return CGSize(width: offset * 60, height: abs(offset) * 10)
    }
    
    private func fanRotation(index: Int, total: Int) -> Angle {
        guard total > 1 else { return .zero }
        let centerIndex = Double(total - 1) / 2.0
        let offset = Double(index) - centerIndex
        return .degrees(offset * 5)
    }
    
    // MARK: - Gestures
    
    private func cardGesture(for card: CardTemplate) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                if appMode.draggingCardId == nil && !appMode.isDragging {
                    // Start drag
                    appMode.enter(.dragging(DragPayload(type: .cardTemplate(card.id), source: tab)))
                    if appMode.draggingCardId == card.id {
                        dragCoordinator.startDrag(payload: DragPayload(type: .cardTemplate(card.id), source: tab))
                    } else {
                        return
                    }
                }
                dragCoordinator.dragLocation = value.location
            }
            .onEnded { _ in
                // Drop handled by parent
            }
    }
    
    private var previewCard: CardTemplate? {
        guard let id = raisedCardId else { return nil }
        return cardStore.get(id: id)
    }
}

// MARK: - Card View

struct CardView: View {
    let template: CardTemplate
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: template.icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // Title
            Text(template.title)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Duration
            Text(formatDuration(template.defaultDuration))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(12)
        .frame(width: 100, height: 140)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private var cardBackground: some View {
        LinearGradient(
            colors: [Color.purple.opacity(0.8), Color.purple.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return "\(minutes) min"
    }
}

private struct CardPreviewPanel: View {
    let template: CardTemplate
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("\(Int(template.defaultDuration / 60)) min · \(template.category.rawValue.capitalized)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }
}
