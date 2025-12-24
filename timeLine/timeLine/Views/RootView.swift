import SwiftUI
import TimeLineCore

struct RootView: View {
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var deckStore: DeckStore
    
    @StateObject private var appMode = AppModeManager()
    @StateObject private var dragCoordinator = DragDropCoordinator()
    @StateObject private var petVisibility = PetVisibilityController()
    
    @AppStorage("useMapPrototype") private var useMapPrototype = true  // default to map
    
    @State private var nodeFrames: [UUID: CGRect] = [:]
    @State private var lastDeckBatch: DeckBatchResult?
    @State private var showDeckToast = false
    @State private var deckPlacementCooldownUntil: Date?
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // 1. Base layer: Map or Battle/Rest screens
            baseLayer
            
            // 2. Deck overlay (visible during drag too, dimmed)
            deckLayer
            
            // 3. Dragging card on top
            draggingLayer
            
            // 5. Bottom sheet (locked when overlay active)
            // Note: MapBottomSheet is now inside RogueMapView, we just need to pass isLocked
        }
        .environmentObject(appMode)
        .environmentObject(dragCoordinator)
        .environmentObject(petVisibility)
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
        .task {
            cardStore.seedDefaultsIfNeeded()
            deckStore.seedDefaultsIfNeeded(using: cardStore)
        }
    }
    
    // MARK: - Layers
    
    @ViewBuilder
    private var baseLayer: some View {
        switch engine.state {
        case .idle, .victory, .retreat:
            Group {
                if useMapPrototype {
                    RogueMapView()
                } else {
                    TimelineView()
                }
            }
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
        case .placeCard(let cardTemplateId, let anchorNodeId):
            // Create TimelineStore with current session
            let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
            _ = timelineStore.placeCardOccurrence(
                cardTemplateId: cardTemplateId,
                anchorNodeId: anchorNodeId,
                using: cardStore
            )
            
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            success = true
            
        case .placeDeck(let deckId, let anchorNodeId):
            guard !isDeckPlacementLocked else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                success = false
                break
            }
            let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
            if let result = timelineStore.placeDeckBatch(
                deckId: deckId,
                anchorNodeId: anchorNodeId,
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            success = false
        }
        
        dragCoordinator.reset()
        appMode.exitDrag(success: success)
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

    @State private var title: String = ""
    @State private var durationMinutes: Double = 25
    @State private var didLoad = false
    
    var body: some View {
        NavigationStack {
            Group {
                if cardStore.get(id: cardTemplateId) != nil {
                    Form {
                        Section("Title") {
                            TextField("Card title", text: $title)
                                .textInputAutocapitalization(.sentences)
                        }
                        
                        Section("Duration") {
                            Stepper(value: $durationMinutes, in: 5...240, step: 5) {
                                Text("\(Int(durationMinutes)) min")
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28, weight: .bold))
                        Text("Card not found")
                            .font(.system(.headline, design: .rounded))
                    }
                    .foregroundColor(.secondary)
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if !didLoad {
                loadCard()
                didLoad = true
            }
        }
    }
    
    private func loadCard() {
        guard let card = cardStore.get(id: cardTemplateId) else { return }
        title = card.title
        durationMinutes = min(240, max(5, card.defaultDuration / 60))
    }
    
    private func saveChanges() {
        guard var card = cardStore.get(id: cardTemplateId) else { return }
        card.title = title
        card.defaultDuration = durationMinutes * 60
        cardStore.update(card)
    }
}
