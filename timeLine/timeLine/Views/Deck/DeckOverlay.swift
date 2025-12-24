import SwiftUI
import TimeLineCore

// MARK: - Deck Overlay

struct DeckOverlay: View {
    let tab: DeckTab
    let isDimmed: Bool
    
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var appMode: AppModeManager
    
    init(tab: DeckTab, isDimmed: Bool = false) {
        self.tab = tab
        self.isDimmed = isDimmed
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Tip prompt
            if !isDimmed {
                Text("Drag a card or deck onto the timeline")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 12)
            }
            
            // Tab bar
            if !isDimmed {
                tabBar
                    .padding(.bottom, 8)
            }
            
            // Content based on tab
            Group {
                switch tab {
                case .cards:
                    CardFanView(tab: tab)
                case .decks:
                    DecksTabView()
                case .create:
                    CreateTabView()
                }
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(isDimmed ? 0.3 : 0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isDimmed {
                        appMode.closeDeck()
                    }
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if !isDimmed && value.translation.height > 80 {
                                appMode.exitToHome()
                            }
                        }
                )
        )
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 24) {
            ForEach(DeckTab.allCases, id: \.self) { t in
                Button {
                    appMode.enter(.deckOverlay(t))
                } label: {
                    Text(tabTitle(t))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(tab == t ? .bold : .medium)
                        .foregroundColor(tab == t ? .white : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(tab == t ? Color.white.opacity(0.15) : Color.clear)
                        )
                }
            }
        }
    }

    private func tabTitle(_ tab: DeckTab) -> String {
        switch tab {
        case .cards:
            return "Cards"
        case .decks:
            return "Decks"
        case .create:
            return "Create"
        }
    }
}

// MARK: - Decks Tab

private struct DecksTabView: View {
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    @State private var previewDeckId: UUID?
    @State private var deckEditCooldownUntil: Date?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button {
                    guard !appMode.isDragging else { return }
                    appMode.enter(.deckOverlay(.create))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add Deck")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            if let preview = previewDeck {
                DeckPreviewPanel(deck: preview)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(deckStore.orderedDecks()) { deck in
                        DeckCard(deck: deck)
                            .onTapGesture {
                                guard !appMode.isDragging else { return }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    previewDeckId = previewDeckId == deck.id ? nil : deck.id
                                }
                            }
                            .onLongPressGesture(minimumDuration: 0.5) {
                                guard !appMode.isDragging, !isDeckEditLocked else { return }
                                appMode.enterDeckEdit(deckId: deck.id)
                                setDeckEditCooldown()
                            }
                            .gesture(deckDragGesture(for: deck))
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 160)
        }
    }
    
    private func deckDragGesture(for deck: DeckTemplate) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                if appMode.draggingDeckId == nil && !appMode.isDragging {
                    appMode.enter(.dragging(DragPayload(type: .deck(deck.id), source: .decks)))
                    if appMode.draggingDeckId == deck.id {
                        let summary = DeckDragSummary(
                            count: deck.count,
                            duration: deckStore.totalDuration(for: deck, using: cardStore)
                        )
                        dragCoordinator.startDeckDrag(
                            payload: DragPayload(type: .deck(deck.id), source: .decks),
                            summary: summary
                        )
                    } else {
                        return
                    }
                }
                dragCoordinator.dragLocation = value.location
            }
            .onEnded { _ in }
    }
    
    private var previewDeck: DeckTemplate? {
        guard let id = previewDeckId else { return nil }
        return deckStore.get(id: id)
    }
    
    private var isDeckEditLocked: Bool {
        if let until = deckEditCooldownUntil {
            return Date() < until
        }
        return false
    }
    
    private func setDeckEditCooldown() {
        deckEditCooldownUntil = Date().addingTimeInterval(1.2)
    }
}

private struct DeckCard: View {
    let deck: DeckTemplate
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var cardStore: CardTemplateStore
    
    var body: some View {
        let duration = deckStore.totalDuration(for: deck, using: cardStore)
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.cyan)
            
            Text(deck.title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("\(deck.count) cards · \(formatDuration(duration))")
                .font(.system(.caption2))
                .foregroundColor(.gray)
        }
        .padding(16)
        .frame(width: 170, height: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return "\(minutes) min"
    }
}

private struct DeckPreviewPanel: View {
    let deck: DeckTemplate
    
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var cardStore: CardTemplateStore
    
    var body: some View {
        let duration = deckStore.totalDuration(for: deck, using: cardStore)
        let names = deck.cardTemplateIds.compactMap { cardStore.get(id: $0)?.title }
        let subtitle = names.prefix(3).joined(separator: " · ")
        
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.cyan)
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("\(deck.count) cards · \(Int(duration / 60)) min")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.gray)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.gray.opacity(0.8))
                        .lineLimit(1)
                }
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

// MARK: - Create Tab

private struct CreateTabView: View {
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var deckStore: DeckStore
    
    @State private var cardTitle = ""
    @State private var cardMinutes = 25.0
    @State private var deckTitle = ""
    @State private var selectedCardIds: Set<UUID> = []
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("CREATE CARD")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.cyan.opacity(0.8))
                
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Card title", text: $cardTitle)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    
                    Stepper(value: $cardMinutes, in: 5...240, step: 5) {
                        Text("\(Int(cardMinutes)) min")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Button("Add Card") {
                        addCard()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.cyan)
                }
                
                Text("CREATE DECK")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.cyan.opacity(0.8))
                    .padding(.top, 6)
                
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Deck title", text: $deckTitle)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(cardStore.orderedTemplates()) { card in
                            Button {
                                toggleSelection(card.id)
                            } label: {
                                HStack {
                                    Image(systemName: selectedCardIds.contains(card.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedCardIds.contains(card.id) ? .cyan : .gray)
                                    Text(card.title)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(card.defaultDuration / 60)) min")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.04))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Button("Save Deck") {
                        saveDeck()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 220)
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedCardIds.contains(id) {
            selectedCardIds.remove(id)
        } else {
            selectedCardIds.insert(id)
        }
    }
    
    private func addCard() {
        let trimmed = cardTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let template = CardTemplate(
            title: trimmed,
            icon: "bolt.fill",
            defaultDuration: cardMinutes * 60,
            tags: [],
            energyColor: .focus,
            category: .work,
            style: .focus
        )
        cardStore.add(template)
        cardTitle = ""
    }
    
    private func saveDeck() {
        let trimmed = deckTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let selectedCards = cardStore.order.filter { selectedCardIds.contains($0) }
        guard !selectedCards.isEmpty else { return }
        let deck = DeckTemplate(title: trimmed, cardTemplateIds: selectedCards)
        deckStore.add(deck)
        deckTitle = ""
        selectedCardIds.removeAll()
    }
}
