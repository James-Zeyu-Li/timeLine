import SwiftUI
import Foundation
import TimeLineCore

// MARK: - Decks Tab

struct DecksTabView: View {
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    @State private var previewDeckId: UUID?
    @State private var deckEditCooldownUntil: Date?
    @State private var showDeckBuilder = false
    @State private var deckTitle = ""
    @State private var selectedCardIds: Set<UUID> = []

    @State private var showRoutinePicker = false
    @State private var deckFrames: [UUID: CGRect] = [:]
    
    var body: some View {
        VStack(spacing: 12) {
            routineDecksSection
            
            HStack {
                Spacer()
                Button {
                    guard !appMode.isDragging else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showDeckBuilder.toggle()
                    }
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
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(key: OverlayItemFramePreferenceKey.self, value: [deck.id: proxy.frame(in: .global)])
                                }
                            )
                            .gesture(deckDragGesture(for: deck))
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 160)
            
            if showDeckBuilder {
                deckBuilder
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(isPresented: $showRoutinePicker) {
            RoutinePickerView()
        }
        .onPreferenceChange(OverlayItemFramePreferenceKey.self) { frames in
            self.deckFrames = frames
        }
    }
    
    private func deckDragGesture(for deck: DeckTemplate) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                if appMode.draggingDeckId == nil && !appMode.isDragging {
                    let frame = deckFrames[deck.id] ?? .zero
                    let center = CGPoint(x: frame.midX, y: frame.midY)
                    let start = value.startLocation
                    let offset = CGSize(width: center.x - start.x, height: center.y - start.y)
                    
                    let payload = DragPayload(type: .deck(deck.id), source: .decks, initialOffset: offset)
                    appMode.enter(.dragging(payload))
                    
                    let summary = DeckDragSummary(
                        count: deck.count,
                        duration: deckStore.totalDuration(for: deck, using: cardStore)
                    )
                    dragCoordinator.startDeckDrag(
                        payload: payload,
                        summary: summary
                    )
                }
                dragCoordinator.dragLocation = value.location
            }
            .onEnded { _ in
                dragCoordinator.isDragEnded = true
            }
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

    private var routineDecksSection: some View {
        let routines = Array(RoutineProvider.defaults.prefix(3))
        let accents: [(String, Color)] = [
            ("sun.horizon.fill", .orange),
            ("brain.head.profile", .purple),
            ("moon.stars.fill", .indigo)
        ]
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ROUTINE DECKS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4).opacity(0.8)) // Chapter brown
                
                Spacer()
                
                Button {
                    showRoutinePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(.caption, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2)) // Chapter activity orange
                }
                .buttonStyle(.plain)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                        let accent = accents[index % accents.count]
                        RoutineDeckCard(
                            title: routine.name,
                            icon: accent.0,
                            color: accent.1,
                            taskCount: routine.presets.count,
                            isEnabled: !appMode.isDragging
                        ) {
                            deckStore.addDeck(from: routine, using: cardStore)
                            appMode.enter(.deckOverlay(.decks))
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var deckBuilder: some View {
        let cards = cardStore.orderedTemplates(includeEphemeral: false)
        return VStack(alignment: .leading, spacing: 12) {
            Text("CREATE DECK")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundColor(.cyan.opacity(0.8))
            
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
                ForEach(cards) { card in
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
            .disabled(deckTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCardIds.isEmpty)
        }
        .padding(.horizontal, 24)
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedCardIds.contains(id) {
            selectedCardIds.remove(id)
        } else {
            selectedCardIds.insert(id)
        }
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showDeckBuilder = false
        }
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

private struct RoutineDeckCard: View {
    let title: String
    let icon: String
    let color: Color
    let taskCount: Int
    let isEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(taskCount) tasks")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(12)
            .frame(width: 110)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}
