import SwiftUI
import Combine
import TimeLineCore

struct RootView: View {
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var coordinator: TimelineEventCoordinator
    
    @StateObject private var dragCoordinator = DragDropCoordinator()
    
    @State private var nodeFrames: [UUID: CGRect] = [:]
    @State private var lastDeckBatch: DeckBatchResult?
    @State private var showDeckToast = false
    @State private var deckPlacementCooldownUntil: Date?
    @State private var showSettings = false
    @State private var showPlanSheet = false
    @State private var showFieldJournal = false
    @State private var showQuickBuilder = false
    @State private var showSettlement = false
    @State private var reminderTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // 温馨的草地背景
            // 16.1 Global Background (Parchment)
            PixelTheme.background
                .ignoresSafeArea()
            
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
                        // Initialize start location if not set
                        if dragCoordinator.initialDragLocation == nil {
                            dragCoordinator.initialDragLocation = value.location
                        }
                        
                        // Calculate offset relative to where drag mode STARTED
                        if let start = dragCoordinator.initialDragLocation {
                            dragCoordinator.dragOffset = CGSize(
                                width: value.location.x - start.x,
                                height: value.location.y - start.y
                            )
                        }
                        
                        dragCoordinator.updatePosition(
                            value.location,
                            nodeFrames: nodeFrames,
                            allowedNodeIds: droppableNodeIds
                        )
                    } else {
                        // Ensure we reset if no longer dragging (safety)
                        if dragCoordinator.initialDragLocation != nil {
                            dragCoordinator.initialDragLocation = nil
                            dragCoordinator.dragOffset = .zero
                        }
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
        .sheet(isPresented: $showSettlement) {
            DailySettlementView()
        }
        .onReceive(coordinator.uiEvents) { event in
            if case .showSettlement = event {
                showSettlement = true
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
        .overlay(alignment: .bottom) {
            if shouldShowReminder, let event = coordinator.pendingReminder {
                ReminderBanner(
                    event: event,
                    onComplete: {
                        coordinator.completeReminder(nodeId: event.nodeId)
                    },
                    onSnooze: {
                        coordinator.snoozeReminder(nodeId: event.nodeId)
                    },
                    onOpen: {
                        openReminderDetails(event)
                    }
                )
                .padding(.bottom, showDeckToast ? 96 : 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if shouldShowRestSuggestion, let event = coordinator.pendingRestSuggestion {
                RestSuggestionBanner(
                    event: event,
                    onRest: {
                        coordinator.acceptRestSuggestion()
                    },
                    onContinue: {
                        coordinator.declineRestSuggestion()
                    }
                )
                .padding(.bottom, showDeckToast ? 96 : 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsFloatingControls {
                GeometryReader { proxy in
                    HUDControlsView(
                        onZap: handleZapTap,
                        onPlan: { showPlanSheet = true },
                        onBackpack: { showFieldJournal = true } // Temporarily map Backpack to Field Journal
                    )
                    .padding(.trailing, 16)
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                .ignoresSafeArea()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showPlanSheet) {
            PlanSheetView()
                .environmentObject(TimelineStore(daySession: daySession, stateManager: stateManager))
                .environmentObject(cardStore)
                .environmentObject(daySession)
                .environmentObject(engine)
                .presentationDetents([.fraction(0.85)])
        }
        .sheet(isPresented: $showFieldJournal) {
            DailySettlementView()
                .environmentObject(engine)
        }
        .sheet(isPresented: $showQuickBuilder) {
            QuickBuilderSheet()
        }
        .sheet(item: explorationReportBinding) { report in
            FocusGroupReportSheet(report: report)
        }
        .task {
            cardStore.seedDefaultsIfNeeded()
            deckStore.seedDefaultsIfNeeded(using: cardStore)
        }
        .onReceive(reminderTimer) { input in
            coordinator.checkReminders(at: input)
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
            if shouldShowGroupFocus {
                GroupFocusView()
                    .transition(.opacity)
            } else {
                BattleView()
                    .transition(.opacity)
            }
            
        case .resting:
            BonfireView()
                .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private var deckLayer: some View {
        switch appMode.mode {
        case .deckOverlay(let tab):
            StrictSheet(tab: tab, isDimmed: false)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .seedTuner:
            SeedTunerOverlay()
                .transition(.opacity) // Overlay manages its own card transition, but this handles the container
        case .dragging(let payload):
            // Keep deck visible but dimmed during drag (only for card/deck drags, not node reordering)
            if case .node = payload.type {
                EmptyView()
            } else {
                StrictSheet(tab: payload.source, isDimmed: true)
                    .allowsHitTesting(false)
            }
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
                    .zIndex(1)
            case .deck(let deckId):
                DraggingDeckView(deckId: deckId)
                    .zIndex(1)
            case .focusGroup(let memberTemplateIds):
                DraggingGroupView(memberTemplateIds: memberTemplateIds)
                    .zIndex(1)
            case .node:
                EmptyView() // Node dragging not implemented in UI layer
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

    private var explorationReportBinding: Binding<FocusGroupFinishedReport?> {
        Binding(
            get: { coordinator.lastExplorationReport },
            set: { _ in coordinator.clearExplorationReport() }
        )
    }

    private var shouldShowRestSuggestion: Bool {
        guard coordinator.pendingRestSuggestion != nil else { return false }
        guard coordinator.pendingReminder == nil else { return false }
        return engine.state != .resting
    }

    private var shouldShowReminder: Bool {
        coordinator.pendingReminder != nil
    }

    private var shouldShowGroupFocus: Bool {
        guard let node = daySession.currentNode else { return false }
        return node.effectiveTaskMode { id in
            cardStore.get(id: id)
        } == .focusGroupFlexible
    }

    private func openReminderDetails(_ event: ReminderEvent) {
        guard let templateId = event.templateId else { return }
        let returnMode: AppMode
        switch appMode.mode {
        case .deckOverlay(let tab):
            returnMode = .deckOverlay(tab)
        default:
            returnMode = .homeCollapsed
        }
        appMode.enter(.cardEdit(cardTemplateId: templateId, returnMode: returnMode))
    }
    
    private var droppableNodeIds: Set<UUID> {
        let upcoming = daySession.nodes.filter { !$0.isCompleted }
        if upcoming.isEmpty {
            return Set(daySession.nodes.map(\.id))
        }
        return Set(upcoming.map(\.id))
    }
    
    // MARK: - Drop Handling
    
    private func handleDrop() {
        let action = dragCoordinator.drop()
        let success: Bool
        
        switch action {
        case .placeCard(let cardTemplateId, let anchorNodeId, let placement):
            // Create TimelineStore with current session
            let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
            if let card = cardStore.get(id: cardTemplateId),
               let remindAt = card.remindAt {
                _ = timelineStore.placeCardOccurrenceByTime(
                    cardTemplateId: cardTemplateId,
                    remindAt: remindAt,
                    using: cardStore,
                    engine: engine
                )
            } else {
                _ = timelineStore.placeCardOccurrence(
                    cardTemplateId: cardTemplateId,
                    anchorNodeId: anchorNodeId,
                    placement: placement,
                    using: cardStore
                )
            }
            
            Haptics.impact(.heavy)
            success = true
            
        case .placeDeck(let deckId, let anchorNodeId, let placement):
            guard !isDeckPlacementLocked else {
                Haptics.impact(.light)
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
                Haptics.impact(.heavy)
                success = true
            } else {
                Haptics.impact(.light)
                success = false
            }
            
        case .placeFocusGroup(let memberTemplateIds, let anchorNodeId, let placement):
            let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
            if timelineStore.placeFocusGroupOccurrence(
                memberTemplateIds: memberTemplateIds,
                anchorNodeId: anchorNodeId,
                placement: placement,
                using: cardStore
            ) != nil {
                Haptics.impact(.heavy)
                success = true
            } else {
                Haptics.impact(.light)
                success = false
            }

        case .moveNode(let nodeId, let anchorNodeId, let placement):
            let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
            guard let currentIndex = daySession.nodes.firstIndex(where: { $0.id == nodeId }),
                  let anchorIndex = daySession.nodes.firstIndex(where: { $0.id == anchorNodeId }) else {
                Haptics.impact(.light)
                success = false
                break
            }
            
            // Timeline is displayed in REVERSED order: visual top = highest data index
            // DragDropCoordinator with axisDirection=.bottomToTop:
            //   - .before = cursor is BELOW target center (user wants to place BELOW target visually)
            //   - .after = cursor is ABOVE target center (user wants to place ABOVE target visually)
            //
            // In reversed display:
            //   - "above" visually = HIGHER data index
            //   - "below" visually = LOWER data index
            //
            // So:
            //   - .after (place above visual) → insert at higher data index = anchorIndex + 1
            //   - .before (place below visual) → insert at anchorIndex
            
            let destinationIndex: Int
            if placement == .after {
                // Place ABOVE anchor visually = HIGHER data index
                destinationIndex = anchorIndex + 1
            } else {
                // Place BELOW anchor visually = AT or BEFORE anchor in data
                destinationIndex = anchorIndex
            }
            
            print("DEBUG moveNode: currentIndex=\(currentIndex), anchorIndex=\(anchorIndex), placement=\(placement)")
            print("DEBUG moveNode: destinationIndex=\(destinationIndex)")
            
            // Check if move would actually change anything
            // For Array.move: moving from X to X or X+1 results in no change
            let wouldActuallyMove = !(destinationIndex == currentIndex || destinationIndex == currentIndex + 1)
            
            if wouldActuallyMove {
                print("DEBUG moveNode: Executing move from \(currentIndex) to \(destinationIndex)")
                let sourceIndexSet = IndexSet(integer: currentIndex)
                timelineStore.moveNode(from: sourceIndexSet, to: destinationIndex)
                Haptics.impact(.medium)
                success = true
            } else {
                print("DEBUG moveNode: Skipping - no actual movement would occur")
                Haptics.impact(.light)
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
            Haptics.impact(.light)
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
                Haptics.impact(.heavy)
                return true
            }
        case .deck(let deckId):
            guard !isDeckPlacementLocked else {
                Haptics.impact(.light)
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
                Haptics.impact(.heavy)
                return true
            }
        case .focusGroup(let memberTemplateIds):
            if timelineStore.placeFocusGroupOccurrenceAtStart(
                memberTemplateIds: memberTemplateIds,
                using: cardStore,
                engine: engine
            ) != nil {
                Haptics.impact(.heavy)
                return true
            }
        case .node:
            // Node moving not implemented yet
            break
        }
        
        Haptics.impact(.light)
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
        if case .focusGroup = dragCoordinator.activePayload?.type {
            return "Drop to place focus group"
        }
        if appMode.draggingDeckId != nil {
            return "Drop to insert deck"
        }
        return "Drop to place first card"
    }
    
    private var emptyDropSubtitle: String? {
        if case .focusGroup(let memberTemplateIds) = dragCoordinator.activePayload?.type {
            let totalSeconds = memberTemplateIds.compactMap { id in
                cardStore.get(id: id)?.defaultDuration
            }.reduce(0, +)
            let minutes = Int(totalSeconds / 60)
            return "Insert \(memberTemplateIds.count) cards · \(minutes) min"
        }
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


    private func handleZapTap() {
        // Zap V2: Seed Tuner
        appMode.enter(.seedTuner)
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



private struct StrictSheet: View {
    let tab: DeckTab
    let isDimmed: Bool

    var body: some View {
        DeckOverlay(tab: tab, isDimmed: isDimmed, allowedTabs: [.cards, .decks])
    }
}



// MARK: - Node Frame Preference Key

struct NodeFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}




