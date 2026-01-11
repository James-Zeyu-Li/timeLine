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
    @State private var showFocusList = false
    @State private var reminderTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
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
                        dragCoordinator.updatePosition(
                            value.location,
                            nodeFrames: nodeFrames,
                            allowedNodeIds: droppableNodeIds
                        )
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
                    DualEntryControlsView(
                        message: "Ready when you are",
                        onStrict: { appMode.enter(.deckOverlay(.cards)) },
                        onTodo: { showFocusList = true },
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
        .sheet(isPresented: $showFocusList) {
            TodoSheet()
                .presentationDetents([.large])
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
            // Keep deck visible but dimmed during drag
            StrictSheet(tab: payload.source, isDimmed: true)
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
            case .focusGroup(let memberTemplateIds):
                DraggingGroupView(memberTemplateIds: memberTemplateIds)
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

private struct DualEntryControlsView: View {
    let message: String
    let onStrict: () -> Void
    let onTodo: () -> Void
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
                Button(action: onStrict) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Strict")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.purple.opacity(0.85))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .accessibilityIdentifier("strictEntryButton")
                .buttonStyle(.plain)

                Button(action: onTodo) {
                    HStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.system(size: 12, weight: .bold))
                        Text("Todo")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.85))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .accessibilityIdentifier("todoEntryButton")
                .buttonStyle(.plain)

                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .accessibilityIdentifier("settingsButton")
                .buttonStyle(.plain)
            }
        }
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

// MARK: - Card Detail Edit Sheet (Placeholder)

struct CardDetailEditSheet: View {
    let cardTemplateId: UUID
    
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
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
                                .accessibilityIdentifier("cardDetailTitleField")
                        }
                        
                        if taskModeBinding.wrappedValue != .reminderOnly {
                            Section("Duration") {
                                Stepper(value: durationMinutesBinding, in: 5...240, step: 5) {
                                    Text("\(Int(durationMinutesBinding.wrappedValue)) min")
                                }
                            }
                        }
                        
                        Section("Task Mode") {
                            Picker("Task Mode", selection: taskModeBinding) {
                                ForEach(taskModeOptions, id: \.rawValue) { mode in
                                    Text(taskModeLabel(mode)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("cardDetailTaskModePicker")
                            .accessibilityValue(taskModeLabel(taskModeBinding.wrappedValue))
                            .disabled(isTaskModeLocked)
                            if isTaskModeLocked {
                                Text("Locked during active battle.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if taskModeBinding.wrappedValue == .reminderOnly {
                            Section("Remind At") {
                                DatePicker(
                                    "Time",
                                    selection: reminderDateBinding,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                            }
                            
                            Section("Lead Time") {
                                Picker("Lead Time", selection: leadTimeBinding) {
                                    ForEach(leadTimeOptions, id: \.self) { minutes in
                                        Text(leadTimeLabel(minutes)).tag(minutes)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        } else {
                            Section("Complete Within") {
                                Picker("Complete Within", selection: deadlineWindowBinding) {
                                    ForEach(deadlineOptions, id: \.self) { option in
                                        Text(deadlineLabel(option)).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        
                        Section("Backlog") {
                            Toggle("Save to Backlog", isOn: libraryBinding)
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
    
    private var taskModeBinding: Binding<TaskMode> {
        Binding(
            get: { draft?.taskMode ?? .focusStrictFixed },
            set: { newValue in
                guard var current = draft else { return }
                current.taskMode = newValue
                if newValue == .reminderOnly {
                    if current.remindAt == nil {
                        current.remindAt = Date().addingTimeInterval(3600)
                    }
                    current.deadlineWindowDays = nil
                } else {
                    current.remindAt = nil
                    current.leadTimeMinutes = 0
                }
                draft = current
            }
        )
    }
    
    private var taskModeOptions: [TaskMode] {
        [.focusStrictFixed, .focusGroupFlexible, .reminderOnly]
    }

    private var leadTimeOptions: [Int] {
        [0, 5, 10, 30, 60]
    }

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: { draft?.remindAt ?? Date().addingTimeInterval(3600) },
            set: { newValue in
                guard var current = draft else { return }
                current.remindAt = newValue
                draft = current
            }
        )
    }

    private var leadTimeBinding: Binding<Int> {
        Binding(
            get: { draft?.leadTimeMinutes ?? 0 },
            set: { newValue in
                guard var current = draft else { return }
                current.leadTimeMinutes = newValue
                draft = current
            }
        )
    }

    private var deadlineOptions: [Int?] {
        [nil, 1, 3, 5, 7]
    }

    private var deadlineWindowBinding: Binding<Int?> {
        Binding(
            get: { draft?.deadlineWindowDays },
            set: { newValue in
                guard var current = draft else { return }
                current.deadlineWindowDays = newValue
                draft = current
            }
        )
    }

    private var libraryBinding: Binding<Bool> {
        Binding(
            get: { libraryStore.entry(for: cardTemplateId) != nil },
            set: { isOn in
                if isOn {
                    libraryStore.add(templateId: cardTemplateId)
                } else {
                    libraryStore.remove(templateId: cardTemplateId)
                }
                stateManager.requestSave()
            }
        )
    }
    
    private func taskModeLabel(_ mode: TaskMode) -> String {
        switch mode {
        case .focusStrictFixed:
            return "Focus Fixed"
        case .focusGroupFlexible:
            return "Focus Flex"
        case .reminderOnly:
            return "Reminder"
        }
    }

    private func leadTimeLabel(_ minutes: Int) -> String {
        if minutes == 0 {
            return "On Time"
        }
        return "\(minutes)m early"
    }

    private func deadlineLabel(_ option: Int?) -> String {
        guard let option else { return "Off" }
        return "\(option)d"
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
        updateOccurrences(for: draft)
    }
    
    private func updateOccurrences(for template: CardTemplate) {
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        for node in daySession.nodes where !node.isCompleted {
            guard case .battle(let boss) = node.type,
                  boss.templateId == template.id else { continue }
            timelineStore.updateNode(id: node.id, payload: template)
        }
    }

    private var isTaskModeLocked: Bool {
        engine.state == .fighting || engine.state == .paused || engine.state == .frozen
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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exploration Report")
                        .font(.headline)
                    Text(report.taskName)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total \(TimeFormatter.formatDuration(report.totalFocusedSeconds))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()

                if visibleEntries.isEmpty {
                    Text("No focused time recorded.")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                } else {
                    ForEach(visibleEntries, id: \.templateId) { entry in
                        let template = cardStore.get(id: entry.templateId)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(template?.title ?? "Task")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(TimeFormatter.formatDuration(entry.focusedSeconds))
                                    .foregroundColor(PixelTheme.accent)
                            }
                            if let template, template.isEphemeral {
                                Button("Save as Template") {
                                    saveEphemeralTemplate(template)
                                }
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.cyan)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                if !timelineSegments.isEmpty {
                    Divider()
                    Text("Timeline")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                    VStack(spacing: 8) {
                        ForEach(timelineSegments, id: \.startedAt) { segment in
                            HStack(spacing: 12) {
                                Text(timeRangeLabel(for: segment))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text(cardStore.get(id: segment.templateId)?.title ?? "Task")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(TimeFormatter.formatDuration(segment.duration))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(PixelTheme.accent)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.cornerLarge)
                    .fill(Color(white: 0.08))
            )
            .padding(16)
            .navigationTitle("Finished")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
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
}
