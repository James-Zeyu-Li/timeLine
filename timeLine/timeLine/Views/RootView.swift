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
                        onBackpack: { appMode.enter(.deckOverlay(.library)) }
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
        .sheet(isPresented: $showPlanSheet) {
            PlanSheetView()
                .environmentObject(TimelineStore(daySession: daySession, stateManager: stateManager))
                .environmentObject(cardStore)
                .presentationDetents([.fraction(0.9)]) // Large but not full? Or .large?
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
        // Quick Entry: "Focus", 25m, @focus
        // User requested ability to have "no name" or easily editable name.
        // We use a generic "Focus" which acts as a placeholder.
        let input = "Focus 25m @focus"
        guard let result = QuickEntryParser.parseDetailed(input: input) else { return }
        
        let template = result.template
        // Add transient template to store first
        cardStore.add(template)
        
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        
        // Choose insertion method based on timeline state
        let nodeId: UUID?
        if daySession.nodes.isEmpty {
            // If timeline is empty, use the original "at start" method
            nodeId = timelineStore.placeCardOccurrenceAtStart(
                cardTemplateId: template.id,
                using: cardStore,
                engine: engine
            )
        } else {
            // Use queue-jumping insertion for non-empty timeline
            nodeId = timelineStore.placeCardOccurrenceAtCurrent(
                cardTemplateId: template.id,
                using: cardStore,
                engine: engine
            )
        }
        
        if let nodeId = nodeId {
            // Lightning effect haptic feedback
            Haptics.impact(.heavy)
            
            // Transition to "Ready to Fight" state - select the node but don't auto-start
            if let _ = daySession.nodes.first(where: { $0.id == nodeId }) {
                // Set as current node and enter battle view in ready state
                if let nodeIndex = daySession.nodes.firstIndex(where: { $0.id == nodeId }) {
                    daySession.currentIndex = nodeIndex
                }
                
                // Enter battle view but don't start timer automatically
                // The user will see the "Ready to Fight" interface with START button
                appMode.enter(.homeCollapsed) // This will show the battle view since we have a current node
            }
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



struct FocusGroupReportSheet: View {
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var stateManager: AppStateManager
    @Environment(\.dismiss) private var dismiss
    let report: FocusGroupFinishedReport

    private var visibleEntries: [FocusGroupReportEntry] {
        report.entries.filter { $0.focusedSeconds > 0 }
    }

    private var timelineSegments: [FocusGroupReportSegment] {
        report.segments
            .filter { $0.duration > 0 }
            .sorted { $0.startedAt < $1.startedAt }
    }
    
    private var achievementLabel: String {
        let totalMinutes = Int(report.totalFocusedSeconds / 60)
        if totalMinutes >= 120 {
            return "🌟 大丰收！"
        } else if totalMinutes >= 60 {
            return "🌾 好收成！"
        } else if totalMinutes >= 30 {
            return "🌱 有进步！"
        } else {
            return "🌿 好开始！"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section - Harvest Summary (丰收总结)
                    VStack(spacing: 16) {
                        // Treasure Chest Animation Area
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                // Treasure Chest Icon
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(red: 0.545, green: 0.369, blue: 0.235)) // 木纹棕 #8B5E3C
                                    .scaleEffect(1.1)
                                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                                
                                Text("今日收获")
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.2, green: 0.133, blue: 0.067)) // 深棕黑 #332211
                            }
                            Spacer()
                        }
                        
                        // Achievement Banner (飘动的黄色缎带)
                        HStack {
                            Spacer()
                            Text(achievementLabel)
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.2, green: 0.133, blue: 0.067))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.yellow.opacity(0.8))
                                        .shadow(color: .orange.opacity(0.3), radius: 4, x: 2, y: 2)
                                )
                            Spacer()
                        }
                        
                        // Total Focus Time (专注时长显示在木牌上)
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(Color(red: 0.306, green: 0.486, blue: 0.196)) // 森林绿 #4E7C32
                                Text("专注时长")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(red: 0.2, green: 0.133, blue: 0.067))
                            }
                            
                            Text(TimeFormatter.formatDuration(report.totalFocusedSeconds))
                                .font(.system(.largeTitle, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.941, green: 0.502, blue: 0.188)) // 活力橘 #F08030
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.992, green: 0.965, blue: 0.890)) // 浅米色 #FDF6E3
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(red: 0.545, green: 0.369, blue: 0.235), lineWidth: 2) // 木纹棕边框
                                )
                        )
                    }

                    // Task Distribution (任务分布 - 种子包风格)
                    if visibleEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color(red: 0.306, green: 0.486, blue: 0.196).opacity(0.6))
                            Text("今天还没有收获哦")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(Color(red: 0.2, green: 0.133, blue: 0.067).opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            // Section Header with Icon
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(Color(red: 0.306, green: 0.486, blue: 0.196))
                                Text("收获清单")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.2, green: 0.133, blue: 0.067))
                            }
                            
                            // Task Cards (宝可梦卡牌风格)
                            ForEach(visibleEntries, id: \.templateId) { entry in
                                let template = cardStore.get(id: entry.templateId)
                                let progress = report.totalFocusedSeconds > 0 ? entry.focusedSeconds / report.totalFocusedSeconds : 0
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    // Card Header
                                    HStack {
                                        // Pixel Icon
                                        Image(systemName: pixelIcon(for: entry.templateId))
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(pixelColor(for: entry.templateId))
                                            )
                                        
                                        Text(template?.title ?? "Task")
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundColor(Color(red: 0.2, green: 0.133, blue: 0.067))
                                        
                                        Spacer()
                                        
                                        // Time Badge
                                        Text(TimeFormatter.formatDuration(entry.focusedSeconds))
                                            .font(.system(.caption, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule().fill(Color(red: 0.941, green: 0.502, blue: 0.188))
                                            )
                                    }
                                    
                                    // Progress Bar (像素风格进度条)
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            // Background Track
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color(red: 0.545, green: 0.369, blue: 0.235).opacity(0.2))
                                                .frame(height: 12)
                                            
                                            // Progress Fill with Pixel Pattern
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            pixelColor(for: entry.templateId),
                                                            pixelColor(for: entry.templateId).opacity(0.8)
                                                        ]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: geometry.size.width * progress, height: 12)
                                                .animation(.easeInOut(duration: 1.2), value: progress)
                                            
                                        }
                                    }
                                    .frame(height: 12)
                                    
                                    // Save Template Button (像素风格)
                                    if let template, template.isEphemeral {
                                        Button(action: { saveEphemeralTemplate(template) }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "heart.fill")
                                                    .font(.system(size: 12))
                                                Text("收藏种子")
                                                    .font(.system(.caption, design: .rounded))
                                                    .fontWeight(.bold)
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.pink.opacity(0.8))
                                                    .shadow(color: .pink.opacity(0.3), radius: 2, x: 1, y: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white)
                                        .shadow(color: Color(red: 0.545, green: 0.369, blue: 0.235).opacity(0.2), radius: 4, x: 2, y: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(pixelColor(for: entry.templateId).opacity(0.3), lineWidth: 2)
                                        )
                                )
                            }
                        }
                    }

                    // Timeline Section (乡间小径)
                    if !timelineSegments.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "map.fill")
                                    .foregroundColor(Color(red: 0.306, green: 0.486, blue: 0.196))
                                Text("今日足迹")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.2, green: 0.133, blue: 0.067))
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(timelineSegments, id: \.startedAt) { segment in
                                    HStack(spacing: 12) {
                                        // Time Badge
                                        Text(timeRangeLabel(for: segment))
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(Color(red: 0.2, green: 0.133, blue: 0.067).opacity(0.7))
                                            .frame(width: 80, alignment: .leading)
                                        
                                        // Path Marker (路标指示牌)
                                        Image(systemName: "signpost.right.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(pixelColor(for: segment.templateId))
                                        
                                        Text(cardStore.get(id: segment.templateId)?.title ?? "Task")
                                            .font(.system(.caption, design: .rounded))
                                            .fontWeight(.medium)
                                            .foregroundColor(Color(red: 0.2, green: 0.133, blue: 0.067))
                                        
                                        Spacer()
                                        
                                        // Duration with Flower Icon
                                        HStack(spacing: 2) {
                                            Image(systemName: "leaf.fill")
                                                .font(.system(size: 8))
                                                .foregroundColor(Color(red: 0.306, green: 0.486, blue: 0.196))
                                            Text(TimeFormatter.formatDuration(segment.duration))
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(Color(red: 0.2, green: 0.133, blue: 0.067).opacity(0.8))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(red: 0.992, green: 0.965, blue: 0.890).opacity(0.6)) // 浅米色背景
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color(red: 0.306, green: 0.486, blue: 0.196).opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(24)
            }
            .background(
                // 草地背景 with 跳动的像素云朵
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.992, green: 0.965, blue: 0.890), // 浅米色 #FDF6E3
                        Color(red: 0.306, green: 0.486, blue: 0.196).opacity(0.1) // 淡绿色
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("🎉 今日完成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("回到农场") {
                        dismiss()
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.306, green: 0.486, blue: 0.196))
                }
            }
        }
    }

    private func saveEphemeralTemplate(_ template: CardTemplate) {
        var updated = template
        updated.isEphemeral = false
        cardStore.update(updated)
        libraryStore.add(templateId: updated.id)
        stateManager.requestSave()
    }

    private func timeRangeLabel(for segment: FocusGroupReportSegment) -> String {
        guard let start = timelineSegments.first?.startedAt else {
            return TimeFormatter.formatTimer(segment.duration)
        }
        let startOffset = segment.startedAt.timeIntervalSince(start)
        let endOffset = segment.endedAt.timeIntervalSince(start)
        return "\(TimeFormatter.formatTimer(startOffset)) - \(TimeFormatter.formatTimer(endOffset))"
    }
    
    private func pixelColor(for templateId: UUID) -> Color {
        // 像素治愈风格的自然色系
        let hash = templateId.hashValue
        let colors: [Color] = [
            Color(red: 0.306, green: 0.486, blue: 0.196), // 森林绿 #4E7C32
            Color(red: 0.941, green: 0.502, blue: 0.188), // 活力橘 #F08030
            Color(red: 0.545, green: 0.369, blue: 0.235), // 木纹棕 #8B5E3C
            Color(red: 0.2, green: 0.6, blue: 0.8),       // 天蓝色 (学习)
            Color(red: 0.8, green: 0.4, blue: 0.6),       // 粉紫色 (创作)
            Color(red: 0.6, green: 0.8, blue: 0.4),       // 草绿色 (家务)
        ]
        return colors[abs(hash) % colors.count]
    }
    
    private func pixelIcon(for templateId: UUID) -> String {
        // 像素风格的彩色小物件图标
        let hash = templateId.hashValue
        let icons = [
            "laptopcomputer",      // 迷你电脑屏幕 (编程)
            "envelope.fill",       // 带红漆的小信封 (邮件)
            "book.fill",          // 小书本 (学习)
            "house.fill",         // 小房子 (家务)
            "paintbrush.fill",    // 画笔 (创作)
            "gamecontroller.fill", // 游戏手柄 (娱乐)
        ]
        return icons[abs(hash) % icons.count]
    }
}
