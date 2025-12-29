import SwiftUI
import TimeLineCore

struct RootView: View {
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var appMode: AppModeManager
    
    @StateObject private var dragCoordinator = DragDropCoordinator()
    
    @State private var nodeFrames: [UUID: CGRect] = [:]
    @State private var lastDeckBatch: DeckBatchResult?
    @State private var showDeckToast = false
    @State private var deckPlacementCooldownUntil: Date?
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // 1. Base layer: Map or Battle/Rest screens
            baseLayer
            
            // 2. Deck overlay (visible during drag too, dimmed)
            deckLayer
            
            // 3. Empty timeline drop target (when no nodes exist)
            emptyDropLayer
            
            // 3. Dragging card on top
            draggingLayer
            
            // 5. Bottom sheet (removed)
        }
        .environmentObject(appMode)
        .environmentObject(dragCoordinator)
        .animation(.easeInOut, value: engine.state)
        .animation(.spring(response: 0.35), value: appMode.mode)
        .onPreferenceChange(NodeFrameKey.self) { frames in
            nodeFrames = frames
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if appMode.isDragging {
                        dragCoordinator.updatePosition(value.location, nodeFrames: nodeFrames)
                    }
                }
                .onEnded { _ in
                    if appMode.isDragging {
                        handleDrop()
                    }
                }
        )
        .sheet(isPresented: cardEditBinding) {
            if case .cardEdit(let id, _) = appMode.mode {
                CardDetailEditSheet(cardTemplateId: id)
            }
        }
        .sheet(isPresented: deckEditBinding) {
            if case .deckEdit(let id, _) = appMode.mode {
                DeckDetailEditSheet(deckId: id)
            }
        }
        .overlay(alignment: .bottom) {
            if showDeckToast, let batch = lastDeckBatch {
                DeckPlacementToast(
                    title: "Deck placed",
                    onUndo: {
                        undoLastDeckBatch(batch)
                    }
                )
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsFloatingControls {
                GeometryReader { proxy in
                    FloatingControlsView(
                        message: "Ready when you are",
                        onAdd: { appMode.enter(.deckOverlay(.cards)) },
                        onSettings: { showSettings = true }
                    )
                    .padding(.trailing, 16)
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task {
            cardStore.seedDefaultsIfNeeded()
            deckStore.seedDefaultsIfNeeded(using: cardStore)
        }
    }
    
    // MARK: - Layers
    
    @ViewBuilder
    private var baseLayer: some View {
        switch engine.state {
        case .idle, .victory, .retreat, .frozen:
            RogueMapView()
            .transition(.opacity)
            
        case .fighting, .paused:
            BattleView()
                .transition(.opacity)
            
        case .resting:
            BonfireView()
                .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private var deckLayer: some View {
        switch appMode.mode {
        case .deckOverlay(let tab):
            DeckOverlay(tab: tab, isDimmed: false)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .dragging(let payload):
            // Keep deck visible but dimmed during drag
            DeckOverlay(tab: payload.source, isDimmed: true)
                .allowsHitTesting(false)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var draggingLayer: some View {
        switch appMode.mode {
        case .dragging(let payload):
            switch payload.type {
            case .cardTemplate(let id):
                DraggingCardView(cardId: id)
            case .deck(let deckId):
                DraggingDeckView(deckId: deckId)
            }
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var emptyDropLayer: some View {
        if appMode.isDragging && daySession.nodes.isEmpty {
            EmptyDropZoneView(
                title: emptyDropTitle,
                subtitle: emptyDropSubtitle
            )
        }
    }
    
    private var cardEditBinding: Binding<Bool> {
        Binding(
            get: {
                if case .cardEdit = appMode.mode { return true }
                return false
            },
            set: { isPresented in
                if !isPresented {
                    appMode.exitCardEdit()
                }
            }
        )
    }
    
    private var deckEditBinding: Binding<Bool> {
        Binding(
            get: {
                if case .deckEdit = appMode.mode { return true }
                return false
            },
            set: { isPresented in
                if !isPresented {
                    appMode.exitDeckEdit()
                }
            }
        )
    }
    
    // MARK: - Drop Handling
    
    private func handleDrop() {
        let action = dragCoordinator.drop()
        let success: Bool
        
        switch action {
        case .placeCard(let cardTemplateId, let anchorNodeId, let placement):
            // Create TimelineStore with current session
            let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
            _ = timelineStore.placeCardOccurrence(
                cardTemplateId: cardTemplateId,
                anchorNodeId: anchorNodeId,
                placement: placement,
                using: cardStore
            )
            
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            success = true
            
        case .placeDeck(let deckId, let anchorNodeId, let placement):
            guard !isDeckPlacementLocked else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                success = false
                break
            }
            let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
            if let result = timelineStore.placeDeckBatch(
                deckId: deckId,
                anchorNodeId: anchorNodeId,
                placement: placement,
                using: deckStore,
                cardStore: cardStore
            ) {
                lastDeckBatch = result
                showDeckToast = true
                scheduleToastDismiss()
                setDeckPlacementCooldown()
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                success = true
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                success = false
            }
            
        case .cancel:
            success = handleEmptyDropFallback()
        }
        
        dragCoordinator.reset()
        appMode.exitDrag(success: success)
    }
    
    private func handleEmptyDropFallback() -> Bool {
        guard daySession.nodes.isEmpty,
              let payload = dragCoordinator.activePayload else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return false
        }
        
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        switch payload.type {
        case .cardTemplate(let cardId):
            if timelineStore.placeCardOccurrenceAtStart(
                cardTemplateId: cardId,
                using: cardStore,
                engine: engine
            ) != nil {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                return true
            }
        case .deck(let deckId):
            guard !isDeckPlacementLocked else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                return false
            }
            if let result = timelineStore.placeDeckBatchAtStart(
                deckId: deckId,
                using: deckStore,
                cardStore: cardStore,
                engine: engine
            ) {
                lastDeckBatch = result
                showDeckToast = true
                scheduleToastDismiss()
                setDeckPlacementCooldown()
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                return true
            }
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        return false
    }
    
    private var isDeckPlacementLocked: Bool {
        if let until = deckPlacementCooldownUntil {
            return Date() < until
        }
        return false
    }
    
    private func setDeckPlacementCooldown() {
        deckPlacementCooldownUntil = Date().addingTimeInterval(1.2)
    }
    
    private func scheduleToastDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                showDeckToast = false
            }
        }
    }
    
    private func undoLastDeckBatch(_ batch: DeckBatchResult) {
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.undoLastBatch(batchId: batch.batchId)
        lastDeckBatch = nil
        showDeckToast = false
    }
    
    private var emptyDropTitle: String {
        if appMode.draggingDeckId != nil {
            return "Drop to insert deck"
        }
        return "Drop to place first card"
    }
    
    private var emptyDropSubtitle: String? {
        guard let summary = dragCoordinator.activeDeckSummary else { return nil }
        let minutes = Int(summary.duration / 60)
        return "Insert \(summary.count) cards · \(minutes) min"
    }
    
    private var showsFloatingControls: Bool {
        if appMode.isOverlayActive { return false }
        switch engine.state {
        case .idle, .victory, .retreat:
            return true
        case .fighting, .paused, .frozen, .resting:
            return false
        }
    }
}

private struct EmptyDropZoneView: View {
    let title: String
    let subtitle: String?
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                .foregroundColor(Color.white.opacity(0.35))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                )
        )
        .padding(.horizontal, 40)
        .transition(.opacity)
        .allowsHitTesting(false)
    }
}

private struct FloatingControlsView: View {
    let message: String
    let onAdd: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(message)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            
            HStack(spacing: 10) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.cyan.opacity(0.85))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Node Frame Preference Key

struct NodeFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Card Detail Edit Sheet (Placeholder)

struct CardDetailEditSheet: View {
    let cardTemplateId: UUID
    
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var appMode: AppModeManager

    @State private var draft: CardTemplate?
    @State private var cardMissing = false
    
    var body: some View {
        NavigationStack {
            Group {
                if cardMissing {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28, weight: .bold))
                        Text("Card not found")
                            .font(.system(.headline, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                } else if draft != nil {
                    Form {
                        Section("Title") {
                            TextField("Card title", text: titleBinding)
                                .textInputAutocapitalization(.sentences)
                        }
                        
                        Section("Duration") {
                            Stepper(value: durationMinutesBinding, in: 5...240, step: 5) {
                                Text("\(Int(durationMinutesBinding.wrappedValue)) min")
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appMode.exitCardEdit()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        appMode.exitCardEdit()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
        .onAppear {
            loadCardIfNeeded()
        }
    }
    
    private var titleBinding: Binding<String> {
        Binding(
            get: { draft?.title ?? "" },
            set: { newValue in
                guard var current = draft else { return }
                current.title = newValue
                draft = current
            }
        )
    }
    
    private var durationMinutesBinding: Binding<Double> {
        Binding(
            get: { (draft?.defaultDuration ?? 1500) / 60 },
            set: { newValue in
                guard var current = draft else { return }
                let clamped = min(240, max(5, newValue))
                current.defaultDuration = clamped * 60
                draft = current
            }
        )
    }
    
    private var isSaveDisabled: Bool {
        let trimmed = draft?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty
    }
    
    private func loadCardIfNeeded() {
        guard draft == nil, !cardMissing else { return }
        guard let card = cardStore.get(id: cardTemplateId) else {
            cardMissing = true
            return
        }
        draft = card
    }
    
    private func saveChanges() {
        guard let draft else { return }
        cardStore.update(draft)
    }
}
