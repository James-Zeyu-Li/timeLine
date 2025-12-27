import SwiftUI
import Combine
import TimeLineCore

struct DeckBatchResult: Equatable {
    let batchId: UUID
    let insertedNodeIds: [UUID]
}

// MARK: - Timeline Store

@MainActor
final class TimelineStore: ObservableObject {
    
    // MARK: - Dependencies
    
    private let daySession: DaySession
    private let stateManager: StateSaver
    private var batchHistory: [UUID: [UUID]] = [:]
    
    // MARK: - Init
    
    init(daySession: DaySession, stateManager: StateSaver) {
        self.daySession = daySession
        self.stateManager = stateManager
    }
    
    // MARK: - Single Write Path
    
    func placeCardOccurrence(
        cardTemplateId: UUID,
        anchorNodeId: UUID,
        using cardStore: CardTemplateStore
    ) -> UUID? {
        guard let card = cardStore.get(id: cardTemplateId) else { return nil }
        guard let anchorIndex = daySession.nodes.firstIndex(where: { $0.id == anchorNodeId }) else { return nil }
        let node = makeNode(from: card)
        daySession.nodes.insert(node, at: anchorIndex + 1)
        stateManager.requestSave()
        return node.id
    }
    
    func placeDeckBatch(
        deckId: UUID,
        anchorNodeId: UUID,
        using deckStore: DeckStore,
        cardStore: CardTemplateStore
    ) -> DeckBatchResult? {
        guard let deck = deckStore.get(id: deckId) else { return nil }
        guard let anchorIndex = daySession.nodes.firstIndex(where: { $0.id == anchorNodeId }) else { return nil }
        guard let nodes = makeNodes(for: deck, using: cardStore), !nodes.isEmpty else { return nil }
        daySession.nodes.insert(contentsOf: nodes, at: anchorIndex + 1)
        stateManager.requestSave()
        
        let batchId = UUID()
        let insertedIds = nodes.map(\.id)
        batchHistory[batchId] = insertedIds
        return DeckBatchResult(batchId: batchId, insertedNodeIds: insertedIds)
    }
    
    func placeCardOccurrenceAtStart(
        cardTemplateId: UUID,
        using cardStore: CardTemplateStore,
        engine: BattleEngine
    ) -> UUID? {
        guard let card = cardStore.get(id: cardTemplateId) else { return nil }
        let node = makeNode(from: card)
        appendNodes([node], engine: engine)
        return node.id
    }
    
    func placeDeckBatchAtStart(
        deckId: UUID,
        using deckStore: DeckStore,
        cardStore: CardTemplateStore,
        engine: BattleEngine
    ) -> DeckBatchResult? {
        guard let deck = deckStore.get(id: deckId) else { return nil }
        guard let nodes = makeNodes(for: deck, using: cardStore), !nodes.isEmpty else { return nil }
        appendNodes(nodes, engine: engine)
        
        let batchId = UUID()
        let insertedIds = nodes.map(\.id)
        batchHistory[batchId] = insertedIds
        return DeckBatchResult(batchId: batchId, insertedNodeIds: insertedIds)
    }
    
    func undoLastBatch(batchId: UUID) {
        guard let insertedNodeIds = batchHistory.removeValue(forKey: batchId) else { return }
        for id in insertedNodeIds.reversed() {
            daySession.deleteNode(id: id)
        }
        stateManager.requestSave()
    }
    
    private func appendNodes(_ newNodes: [TimelineNode], engine: BattleEngine) {
        guard !newNodes.isEmpty else { return }
        
        let shouldActivateFirst = daySession.nodes.isEmpty || daySession.isFinished
        let startIndex = daySession.nodes.count
        
        var nodesToAdd = newNodes
        for index in nodesToAdd.indices {
            nodesToAdd[index].isLocked = true
            nodesToAdd[index].isCompleted = false
        }
        
        if shouldActivateFirst {
            nodesToAdd[0].isLocked = false
            daySession.currentIndex = startIndex
        }
        
        daySession.nodes.append(contentsOf: nodesToAdd)
        
        if engine.state == .idle || engine.state == .victory || engine.state == .retreat {
            daySession.resetCurrentToFirstUpcoming()
        }
        stateManager.requestSave()
    }

    func updateNode(id: UUID, payload: CardTemplate) {
        daySession.updateNode(id: id, payload: payload)
        stateManager.requestSave()
    }
    
    func deleteNode(id: UUID) {
        daySession.deleteNode(id: id)
        stateManager.requestSave()
    }

    func duplicateNode(id: UUID) {
        daySession.duplicateNode(id: id)
        stateManager.requestSave()
    }

    func moveNode(from source: IndexSet, to destination: Int) {
        daySession.moveNode(from: source, to: destination)
        stateManager.requestSave()
    }
    
    func finalizeReorder(isSessionActive: Bool, activeNodeId: UUID?) {
        if isSessionActive, let activeNodeId,
           let newIndex = daySession.nodes.firstIndex(where: { $0.id == activeNodeId }) {
            daySession.currentIndex = newIndex
        } else if !isSessionActive {
            daySession.resetCurrentToFirstUpcoming()
        }
        stateManager.requestSave()
    }
    
    private func makeNode(from card: CardTemplate) -> TimelineNode {
        let boss = Boss(
            id: UUID(),
            name: card.title,
            maxHp: card.defaultDuration,
            style: card.style,
            category: card.category,
            templateId: card.id
        )
        return TimelineNode(type: .battle(boss), isLocked: true)
    }
    
    private func makeNodes(for deck: DeckTemplate, using cardStore: CardTemplateStore) -> [TimelineNode]? {
        guard !deck.cardTemplateIds.isEmpty else { return nil }
        var nodes: [TimelineNode] = []
        nodes.reserveCapacity(deck.cardTemplateIds.count)
        for templateId in deck.cardTemplateIds {
            guard let card = cardStore.get(id: templateId) else { return nil }
            nodes.append(makeNode(from: card))
        }
        return nodes
    }

}
