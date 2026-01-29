import SwiftUI
import TimeLineCore

extension RootView {
    // MARK: - Layers
    
    @ViewBuilder
    var baseLayer: some View {
        switch engine.state {
        case .idle, .victory, .retreat, .frozen:
            if useTimelineV2 {
                TimelineContainerView(onOpenSettings: {
                    showSettings = true
                })
                .transition(.opacity)
            } else {
                RogueMapView(showJumpButton: $showJumpButton, scrollToNowTrigger: $scrollToNowTrigger)
                    .transition(.opacity)
            }
            
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
    var deckLayer: some View {
        switch appMode.mode {
        case .deckOverlay(let tab):
            StrictSheet(tab: tab, isDimmed: false)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .seedTuner:
            SeedTunerOverlay()
                .transition(.opacity) // Overlay manages its own card transition, but this handles the container
        case .dragging(let payload):
            // Keep deck visible but dimmed during drag (only for card/deck drags, not node reordering)
            switch payload.type {
            case .node, .nodeCopy:
                EmptyView()
            default:
                StrictSheet(tab: payload.source, isDimmed: true)
                    .allowsHitTesting(false)
            }
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    var draggingLayer: some View {
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
            case .node(let nodeId):
                DraggingNodeView(nodeId: nodeId)
                    .zIndex(1)
            case .nodeCopy(let nodeId):
                DraggingNodeView(nodeId: nodeId)
                    .zIndex(1)
            }
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    var emptyDropLayer: some View {
        if appMode.isDragging && daySession.nodes.isEmpty {
            EmptyDropZoneView(
                title: viewModel.emptyDropTitle,
                subtitle: viewModel.emptyDropSubtitle
            )
        }
    }
    
    var cardEditBinding: Binding<Bool> {
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
    
    var deckEditBinding: Binding<Bool> {
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

    var explorationReportBinding: Binding<FocusGroupFinishedReport?> {
        Binding(
            get: { coordinator.lastExplorationReport },
            set: { _ in coordinator.clearExplorationReport() }
        )
    }

    var shouldShowRestSuggestion: Bool {
        guard coordinator.pendingRestSuggestion != nil else { return false }
        guard coordinator.pendingReminder == nil else { return false }
        return engine.state != .resting
    }

    var shouldShowReminder: Bool {
        coordinator.pendingReminder != nil
    }

    var shouldShowGroupFocus: Bool {
        guard let node = daySession.currentNode else { return false }
        return node.effectiveTaskMode { id in
            cardStore.get(id: id)
        } == .focusGroupFlexible
    }

    func openReminderDetails(_ event: ReminderEvent) {
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
    
    var droppableNodeIds: Set<UUID> {
        let upcoming = daySession.nodes.filter { !$0.isCompleted }
        if upcoming.isEmpty {
            return Set(daySession.nodes.map(\.id))
        }
        return Set(upcoming.map(\.id))
    }
    
    var showsFloatingControls: Bool {
        if appMode.isOverlayActive { return false }
        switch engine.state {
        case .idle, .victory, .retreat:
            return true
        case .fighting, .paused, .frozen, .resting:
            return false
        }
    }

    func handleZapTap() {
        // Zap V2: Seed Tuner
        appMode.enter(.seedTuner)
    }
}

struct EmptyDropZoneView: View {
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

struct StrictSheet: View {
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
