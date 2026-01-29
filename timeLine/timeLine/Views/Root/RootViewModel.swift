import SwiftUI
import Combine
import TimeLineCore

@MainActor
class RootViewModel: ObservableObject {
    // Dependencies
    private var engine: BattleEngine?
    private var daySession: DaySession?
    private var stateManager: AppStateManager?
    private var cardStore: CardTemplateStore?
    private var deckStore: DeckStore?
    private var appMode: AppModeManager?
    private var dragCoordinator: DragDropCoordinator?
    
    // State
    @Published var lastDeckBatch: DeckBatchResult?
    @Published var showDeckToast = false
    @Published var deckPlacementCooldownUntil: Date?
    
    // MARK: - Binding
    
    func bind(
        engine: BattleEngine,
        daySession: DaySession,
        stateManager: AppStateManager,
        cardStore: CardTemplateStore,
        deckStore: DeckStore,
        appMode: AppModeManager,
        dragCoordinator: DragDropCoordinator
    ) {
        self.engine = engine
        self.daySession = daySession
        self.stateManager = stateManager
        self.cardStore = cardStore
        self.deckStore = deckStore
        self.appMode = appMode
        self.dragCoordinator = dragCoordinator
    }
    
    // MARK: - Drop Handling
    
    func handleDrop() {
        guard let dragCoordinator, let appMode else { return }
        
        let hoveringInside = dragCoordinator.hoveringInside
        let action = dragCoordinator.drop()
        let success: Bool
        
        switch action {
        case .placeCard(let cardTemplateId, let anchorNodeId, let placement):
            success = handlePlaceCard(
                cardTemplateId: cardTemplateId,
                anchorNodeId: anchorNodeId,
                placement: placement,
                hoveringInside: hoveringInside
            )
            
        case .placeDeck(let deckId, let anchorNodeId, let placement):
            success = handlePlaceDeck(deckId: deckId, anchorNodeId: anchorNodeId, placement: placement)
            
        case .placeFocusGroup(let memberTemplateIds, let anchorNodeId, let placement):
            success = handlePlaceFocusGroup(
                memberTemplateIds: memberTemplateIds,
                anchorNodeId: anchorNodeId,
                placement: placement,
                hoveringInside: hoveringInside
            )

        case .moveNode(let nodeId, let anchorNodeId, let placement):
            success = handleMoveNode(nodeId: nodeId, anchorNodeId: anchorNodeId, placement: placement)

        case .copyNode(let nodeId, let anchorNodeId, let placement):
            success = handleCopyNode(nodeId: nodeId, anchorNodeId: anchorNodeId, placement: placement)

        case .cancel:
            success = handleEmptyDropFallback()
        }
        
        // Fix coordinate drift
        appMode.exitDrag(success: success)
        dragCoordinator.reset()
    }
    
    private func handlePlaceCard(
        cardTemplateId: UUID,
        anchorNodeId: UUID,
        placement: DropPlacement,
        hoveringInside: Bool
    ) -> Bool {
        guard let daySession, let stateManager, let cardStore, let engine else { return false }
        
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        if hoveringInside,
           timelineStore.appendFocusGroupMembers(
               memberTemplateIds: [cardTemplateId],
               to: anchorNodeId,
               using: cardStore
           ) {
            Haptics.impact(.heavy)
            return true
        }
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
        return true
    }
    
    private func handlePlaceDeck(deckId: UUID, anchorNodeId: UUID, placement: DropPlacement) -> Bool {
        guard !isDeckPlacementLocked else {
            Haptics.impact(.light)
            return false
        }
        guard let daySession, let stateManager, let cardStore, let deckStore else { return false }
        
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
            return true
        } else {
            Haptics.impact(.light)
            return false
        }
    }
    
    private func handlePlaceFocusGroup(
        memberTemplateIds: [UUID],
        anchorNodeId: UUID,
        placement: DropPlacement,
        hoveringInside: Bool
    ) -> Bool {
        guard let daySession, let stateManager, let cardStore else { return false }
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        if hoveringInside,
           timelineStore.appendFocusGroupMembers(
               memberTemplateIds: memberTemplateIds,
               to: anchorNodeId,
               using: cardStore
           ) {
            Haptics.impact(.heavy)
            return true
        }
        if timelineStore.placeFocusGroupOccurrence(
            memberTemplateIds: memberTemplateIds,
            anchorNodeId: anchorNodeId,
            placement: placement,
            using: cardStore
        ) != nil {
            Haptics.impact(.heavy)
            return true
        } else {
            Haptics.impact(.light)
            return false
        }
    }
    
    private func handleMoveNode(nodeId: UUID, anchorNodeId: UUID, placement: DropPlacement) -> Bool {
        guard let daySession, let stateManager, let engine else { return false }
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        
        guard let currentIndex = daySession.nodes.firstIndex(where: { $0.id == nodeId }),
              let anchorIndex = daySession.nodes.firstIndex(where: { $0.id == anchorNodeId }) else {
            Haptics.impact(.light)
            return false
        }
        
        // Reordering logic
        let destinationIndex: Int
        if placement == .after {
            // Place ABOVE anchor visually = HIGHER data index
            destinationIndex = anchorIndex + 1
        } else {
            // Place BELOW anchor visually = AT or BEFORE anchor in data
            destinationIndex = anchorIndex
        }
        
        let wouldActuallyMove = destinationIndex != currentIndex && destinationIndex != currentIndex + 1
        
        if wouldActuallyMove {
            let sourceIndexSet = IndexSet(integer: currentIndex)
            timelineStore.moveNode(from: sourceIndexSet, to: destinationIndex)
            let isActive = engine.state == .fighting || engine.state == .paused || engine.state == .frozen || engine.state == .resting
            timelineStore.finalizeReorder(isSessionActive: isActive, activeNodeId: daySession.currentNode?.id)
            Haptics.impact(.medium)
            return true
        } else {
            Haptics.impact(.light)
            return false
        }
    }

    private func handleCopyNode(nodeId: UUID, anchorNodeId: UUID, placement: DropPlacement) -> Bool {
        guard let daySession, let stateManager else { return false }
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        if timelineStore.copyNodeOccurrence(nodeId: nodeId, anchorNodeId: anchorNodeId, placement: placement) != nil {
            Haptics.impact(.medium)
            return true
        }
        Haptics.impact(.light)
        return false
    }
    
    private func handleEmptyDropFallback() -> Bool {
        guard let daySession, let dragCoordinator, let stateManager, let cardStore, let deckStore, let engine else {
            Haptics.impact(.light)
            return false
        }
        
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
        case .node, .nodeCopy:
            break
        }
        
        Haptics.impact(.light)
        return false
    }
    
    // MARK: - Deck Logic
    
    var isDeckPlacementLocked: Bool {
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
                self.showDeckToast = false
            }
        }
    }
    
    func undoLastDeckBatch() {
        guard let batch = lastDeckBatch, let daySession, let stateManager else { return }
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.undoLastBatch(batchId: batch.batchId)
        lastDeckBatch = nil
        showDeckToast = false
    }
    
    // MARK: - Empty Drop UI
    
    var emptyDropTitle: String {
        guard let dragCoordinator, let appMode else { return "Drop to place" }
        if case .focusGroup = dragCoordinator.activePayload?.type {
            return "Drop to place focus group"
        }
        if appMode.draggingDeckId != nil {
            return "Drop to insert deck"
        }
        return "Drop to place first card"
    }
    
    var emptyDropSubtitle: String? {
        guard let dragCoordinator, let cardStore else { return nil }
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
}
