import SwiftUI
import Foundation
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
                case .library:
                    LibraryTabView()
                case .decks:
                    DecksTabView()
                }
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(isDimmed ? 0.3 : 0.7)
                .ignoresSafeArea()
                .accessibilityIdentifier("deckOverlayBackground")
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
        case .library:
            return "Library"
        case .decks:
            return "Decks"
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
    @State private var showDeckBuilder = false
    @State private var deckTitle = ""
    @State private var selectedCardIds: Set<UUID> = []
    @State private var showRoutinePicker = false
    
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
                    .foregroundColor(.cyan.opacity(0.8))
                
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
                    .foregroundColor(.cyan)
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
        VStack(alignment: .leading, spacing: 12) {
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

// MARK: - Library Tab

private struct LibraryTabView: View {
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    @State private var isSelecting = false
    @State private var selectedIds: Set<UUID> = []
    @State private var showCardPicker = false
    
    var body: some View {
        let grouped = libraryStore.groupedEntries(using: cardStore)
        let pinned = rows(for: grouped.pinned)
        let others = rows(for: grouped.others)
        
        VStack(spacing: 12) {
            header
            
            if pinned.isEmpty && others.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        if !pinned.isEmpty {
                            section(title: "Pinned / Active", rows: pinned)
                        }
                        if !others.isEmpty {
                            section(title: "Everything Else", rows: others)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, isSelecting ? 70 : 20)
                }
            }
            
            if isSelecting {
                addToGroupButton
            }
        }
        .sheet(isPresented: $showCardPicker) {
            CardLibraryPickerSheet(title: "Add from Cards")
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("Pick or drag tasks onto the map")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Add from Cards") {
                    showCardPicker = true
                }
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
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
                
                Button(isSelecting ? "Done" : "Select") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        isSelecting.toggle()
                        if !isSelecting {
                            selectedIds.removeAll()
                        }
                    }
                }
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(isSelecting ? .white : .cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelecting ? Color.white.opacity(0.15) : Color.cyan.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(isSelecting ? Color.white.opacity(0.2) : Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var addToGroupButton: some View {
        VStack(spacing: 6) {
            Button {
                addSelectedToGroup()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add to Group")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                }
                .foregroundColor(selectedIds.isEmpty ? .gray : .cyan)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(selectedIds.isEmpty ? Color.white.opacity(0.08) : Color.cyan.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(Color.cyan.opacity(selectedIds.isEmpty ? 0.15 : 0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedIds.isEmpty)
            
            Text("生成一个组节点（暂不支持组内切换）")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.bottom, 24)
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Library is empty")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.white)
            Text("Create a card to add it here.")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 40)
    }
    
    private func section(title: String, rows: [LibraryRowData]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))
            
            ForEach(rows) { row in
                LibraryRow(
                    entry: row.entry,
                    template: row.template,
                    isSelecting: isSelecting,
                    isSelected: selectedIds.contains(row.id),
                    onToggle: {
                        toggleSelection(row.id)
                    },
                    onEdit: {
                        appMode.enterCardEdit(cardTemplateId: row.id)
                    }
                )
                .gesture(cardDragGesture(for: row.template))
            }
        }
    }
    
    private func rows(for entries: [LibraryEntry]) -> [LibraryRowData] {
        entries.compactMap { entry in
            guard let template = cardStore.get(id: entry.templateId) else { return nil }
            return LibraryRowData(entry: entry, template: template)
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func addSelectedToGroup() {
        let memberIds = orderedSelection()
        guard !memberIds.isEmpty else { return }

        let shouldAutoStart = ProcessInfo.processInfo.environment["EMPTY_TIMELINE"] == "1"
        if shouldAutoStart {
            daySession.nodes.removeAll()
            daySession.currentIndex = 0
        }
        
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        let newId: UUID?
        if let anchorId = daySession.nodes.last?.id {
            newId = timelineStore.placeFocusGroupOccurrence(
                memberTemplateIds: memberIds,
                anchorNodeId: anchorId,
                using: cardStore
            )
        } else {
            newId = timelineStore.placeFocusGroupOccurrenceAtStart(
                memberTemplateIds: memberIds,
                using: cardStore,
                engine: engine
            )
        }

        if shouldAutoStart, let newId,
           let node = daySession.nodes.first(where: { $0.id == newId }),
           case .battle(let boss) = node.type {
            daySession.setCurrentNode(id: newId)
            engine.startBattle(boss: boss)
            stateManager.requestSave()
        }
        
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            selectedIds.removeAll()
            isSelecting = false
        }
    }
    
    private func orderedSelection() -> [UUID] {
        let ordered = libraryStore.orderedEntries().map(\.templateId)
        let selected = ordered.filter { selectedIds.contains($0) }
        if !selected.isEmpty {
            return selected
        }
        return Array(selectedIds)
    }
    
    private func cardDragGesture(for template: CardTemplate) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard !isSelecting else { return }
                if appMode.draggingCardId == nil && !appMode.isDragging {
                    appMode.enter(.dragging(DragPayload(type: .cardTemplate(template.id), source: .library)))
                    if appMode.draggingCardId == template.id {
                        dragCoordinator.startDrag(payload: DragPayload(type: .cardTemplate(template.id), source: .library))
                    } else {
                        return
                    }
                }
                dragCoordinator.dragLocation = value.location
            }
            .onEnded { _ in }
    }
}

private struct LibraryRowData: Identifiable {
    let entry: LibraryEntry
    let template: CardTemplate
    
    var id: UUID {
        template.id
    }
}

private struct LibraryRow: View {
    let entry: LibraryEntry
    let template: CardTemplate
    let isSelecting: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .cyan : .gray)
            }
            
            Image(systemName: template.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(Int(template.defaultDuration / 60)) min")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    if template.repeatRule != .none {
                        Text(repeatLabel(for: template.repeatRule))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                    if let deadline = entry.deadline {
                        Text(formatDate(deadline))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.cyan.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelecting {
                onToggle()
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            guard !isSelecting else { return }
            onEdit()
        }
    }
    
    private func repeatLabel(for rule: RepeatRule) -> String {
        switch rule {
        case .none:
            return ""
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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
