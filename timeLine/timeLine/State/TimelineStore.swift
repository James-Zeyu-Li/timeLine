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
        placeCardOccurrence(
            cardTemplateId: cardTemplateId,
            anchorNodeId: anchorNodeId,
            placement: .after,
            using: cardStore
        )
    }
    
    func placeCardOccurrence(
        cardTemplateId: UUID,
        anchorNodeId: UUID,
        placement: DropPlacement,
        using cardStore: CardTemplateStore
    ) -> UUID? {
        guard let card = cardStore.get(id: cardTemplateId) else { return nil }
        guard let anchorIndex = daySession.nodes.firstIndex(where: { $0.id == anchorNodeId }) else { return nil }
        let node = makeNode(from: card)
        let insertIndex = placement == .after ? anchorIndex + 1 : anchorIndex
        daySession.nodes.insert(node, at: insertIndex)
        stateManager.requestSave()
        return node.id
    }
    
    func placeDeckBatch(
        deckId: UUID,
        anchorNodeId: UUID,
        using deckStore: DeckStore,
        cardStore: CardTemplateStore
    ) -> DeckBatchResult? {
        placeDeckBatch(
            deckId: deckId,
            anchorNodeId: anchorNodeId,
            placement: .after,
            using: deckStore,
            cardStore: cardStore
        )
    }
    
    func placeDeckBatch(
        deckId: UUID,
        anchorNodeId: UUID,
        placement: DropPlacement,
        using deckStore: DeckStore,
        cardStore: CardTemplateStore
    ) -> DeckBatchResult? {
        guard let deck = deckStore.get(id: deckId) else { return nil }
        guard let anchorIndex = daySession.nodes.firstIndex(where: { $0.id == anchorNodeId }) else { return nil }
        guard let nodes = makeNodes(for: deck, using: cardStore), !nodes.isEmpty else { return nil }
        let insertIndex = placement == .after ? anchorIndex + 1 : anchorIndex
        daySession.nodes.insert(contentsOf: nodes, at: insertIndex)
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
    
    func placeCardOccurrenceAtCurrent(
        cardTemplateId: UUID,
        using cardStore: CardTemplateStore,
        engine: BattleEngine
    ) -> UUID? {
        guard let card = cardStore.get(id: cardTemplateId) else { return nil }
        var node = makeNode(from: card)
        
        let isIdle = engine.state == .idle || engine.state == .victory || engine.state == .retreat
        let baseIndex = min(daySession.currentIndex, daySession.nodes.count)
        let insertIndex = isIdle ? baseIndex : min(baseIndex + 1, daySession.nodes.count)
        
        node.isLocked = isIdle
        node.isCompleted = false
        
        daySession.nodes.insert(node, at: insertIndex)
        
        if isIdle {
            daySession.currentIndex = insertIndex
        }
        
        stateManager.requestSave()
        return node.id
    }

    func placeCardOccurrenceByTime(
        cardTemplateId: UUID,
        remindAt: Date,
        using cardStore: CardTemplateStore,
        engine: BattleEngine
    ) -> UUID? {
        guard let card = cardStore.get(id: cardTemplateId) else { return nil }
        let node = makeNode(from: card)
        if daySession.nodes.isEmpty {
            appendNodes([node], engine: engine)
            return node.id
        }
        let insertIndex = reminderInsertIndex(remindAt: remindAt, engine: engine, excluding: nil)
        daySession.nodes.insert(node, at: insertIndex)
        stateManager.requestSave()
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

    func placeFocusGroupOccurrence(
        memberTemplateIds: [UUID],
        anchorNodeId: UUID,
        using cardStore: CardTemplateStore
    ) -> UUID? {
        placeFocusGroupOccurrence(
            memberTemplateIds: memberTemplateIds,
            anchorNodeId: anchorNodeId,
            placement: .after,
            using: cardStore
        )
    }
    
    func placeFocusGroupOccurrence(
        memberTemplateIds: [UUID],
        anchorNodeId: UUID,
        placement: DropPlacement,
        using cardStore: CardTemplateStore
    ) -> UUID? {
        guard let anchorIndex = daySession.nodes.firstIndex(where: { $0.id == anchorNodeId }) else { return nil }
        guard let node = makeFocusGroupNode(memberTemplateIds: memberTemplateIds, using: cardStore) else { return nil }
        let insertIndex = placement == .after ? anchorIndex + 1 : anchorIndex
        daySession.nodes.insert(node, at: insertIndex)
        stateManager.requestSave()
        return node.id
    }
    
    func placeFocusGroupOccurrenceAtStart(
        memberTemplateIds: [UUID],
        using cardStore: CardTemplateStore,
        engine: BattleEngine
    ) -> UUID? {
        guard let node = makeFocusGroupNode(memberTemplateIds: memberTemplateIds, using: cardStore) else { return nil }
        appendNodes([node], engine: engine)
        return node.id
    }

    func appendFocusGroupMembers(
        memberTemplateIds: [UUID],
        to nodeId: UUID,
        using cardStore: CardTemplateStore
    ) -> Bool {
        guard let index = daySession.nodes.firstIndex(where: { $0.id == nodeId }) else { return false }
        guard case .battle(var boss) = daySession.nodes[index].type,
              var payload = boss.focusGroupPayload else { return false }

        let newTemplates = resolveTemplates(memberTemplateIds, using: cardStore)
        guard !newTemplates.isEmpty else { return false }

        var mergedIds = payload.memberTemplateIds
        var seen = Set(mergedIds)
        for template in newTemplates where !seen.contains(template.id) {
            mergedIds.append(template.id)
            seen.insert(template.id)
        }
        guard mergedIds != payload.memberTemplateIds else { return false }

        let addedDuration = newTemplates.reduce(0) { $0 + $1.defaultDuration }
        let elapsed = boss.maxHp - boss.currentHp
        let updatedMaxHp = max(60, boss.maxHp + addedDuration)
        boss.maxHp = updatedMaxHp
        boss.currentHp = updatedMaxHp - elapsed

        let resolvedTemplates = resolveTemplates(mergedIds, using: cardStore)
        if resolvedTemplates.count > 1 {
            boss.name = resolvedTemplates.map(\.title).joined(separator: " + ")
        } else if let first = resolvedTemplates.first {
            boss.name = first.title
        }
        boss.category = resolvedTemplates.first?.category ?? boss.category

        payload.memberTemplateIds = mergedIds
        if payload.activeIndex >= mergedIds.count {
            payload.activeIndex = max(0, mergedIds.count - 1)
        }
        boss.focusGroupPayload = payload
        daySession.nodes[index].type = .battle(boss)
        stateManager.requestSave()
        return true
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

    func copyNodeOccurrence(
        nodeId: UUID,
        anchorNodeId: UUID,
        placement: DropPlacement
    ) -> UUID? {
        guard let sourceNode = daySession.nodes.first(where: { $0.id == nodeId }) else { return nil }
        guard let anchorIndex = daySession.nodes.firstIndex(where: { $0.id == anchorNodeId }) else { return nil }

        let newNode = cloneNode(from: sourceNode)
        let insertIndex = placement == .after ? anchorIndex + 1 : anchorIndex
        daySession.nodes.insert(newNode, at: insertIndex)
        daySession.refreshLockStates()
        stateManager.requestSave()
        return newNode.id
    }

    func updateNodeByTime(id: UUID, payload: CardTemplate, engine: BattleEngine) {
        // Optimize: Do not save in updateNode internal call, wait for final save
        daySession.updateNode(id: id, payload: payload)
        
        guard let remindAt = payload.remindAt else {
            // If no reminder time, just save the update
            stateManager.requestSave()
            return
        }
        
        guard let currentIndex = daySession.nodes.firstIndex(where: { $0.id == id }) else {
            stateManager.requestSave()
            return
        }
        
        let targetIndex = reminderInsertIndex(remindAt: remindAt, engine: engine, excluding: id)
        
        if targetIndex != currentIndex {
             daySession.moveNode(from: IndexSet(integer: currentIndex), to: targetIndex)
        }
        
        // Single save at the end triggers persistence once
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
    
    // MARK: - Inbox Operations (Phase 17.2)
    
    var inbox: [TimelineNode] {
        daySession.inbox
    }
    
    func addToInbox(
        cardTemplateId: UUID,
        using cardStore: CardTemplateStore
    ) -> UUID? {
        guard let card = cardStore.get(id: cardTemplateId) else { return nil }
        var node = makeNode(from: card)
        node.isUnscheduled = true
        daySession.inbox.append(node)
        stateManager.requestSave()
        return node.id
    }
    
    func deleteFromInbox(nodeId: UUID) {
        if let index = daySession.inbox.firstIndex(where: { $0.id == nodeId }) {
            daySession.inbox.remove(at: index)
            stateManager.requestSave()
        }
    }
    
    func moveFromInboxToStart(nodeId: UUID) {
        // Find and remove from inbox
        guard let index = daySession.inbox.firstIndex(where: { $0.id == nodeId }) else { return }
        let node = daySession.inbox.remove(at: index)
        
        // Reset unscheduled flag
        var activeNode = node
        activeNode.isUnscheduled = false
        
        // Insert at current index (next up)
        // Ensure index is valid
        let insertIndex = min(daySession.currentIndex, daySession.nodes.count)
        daySession.nodes.insert(activeNode, at: insertIndex)
        
        // If we inserted at currentIndex, ensure it is unlocked
        if daySession.nodes.indices.contains(insertIndex) {
            daySession.nodes[insertIndex].isLocked = false
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
            templateId: card.id,
            recommendedStart: card.fixedTime,
            remindAt: card.remindAt,
            leadTimeMinutes: card.leadTimeMinutes
        )
        return TimelineNode(type: .battle(boss), isLocked: true)
    }

    private func cloneNode(from source: TimelineNode) -> TimelineNode {
        switch source.type {
        case .battle(let boss):
            let clonedBoss = Boss(
                id: UUID(),
                name: boss.name,
                maxHp: boss.maxHp,
                style: boss.style,
                category: boss.category,
                templateId: boss.templateId,
                recommendedStart: boss.recommendedStart,
                focusGroupPayload: boss.focusGroupPayload,
                remindAt: boss.remindAt,
                leadTimeMinutes: boss.leadTimeMinutes
            )
            return TimelineNode(
                type: .battle(clonedBoss),
                isCompleted: false,
                isLocked: true,
                taskModeOverride: source.taskModeOverride,
                isUnscheduled: source.isUnscheduled,
                completedAt: nil
            )
        case .bonfire(let duration):
            return TimelineNode(
                type: .bonfire(duration),
                isCompleted: false,
                isLocked: true,
                taskModeOverride: source.taskModeOverride,
                isUnscheduled: source.isUnscheduled,
                completedAt: nil
            )
        case .treasure:
            return TimelineNode(
                type: .treasure,
                isCompleted: false,
                isLocked: true,
                taskModeOverride: source.taskModeOverride,
                isUnscheduled: source.isUnscheduled,
                completedAt: nil
            )
        }
    }

    private func reminderInsertIndex(remindAt: Date, engine: BattleEngine, excluding excludedId: UUID?) -> Int {
        let allNodes = daySession.nodes.filter { $0.id != excludedId }
        let upcoming = allNodes.filter { !$0.isCompleted }
        guard !upcoming.isEmpty else { return allNodes.count }
        let now = Date()
        let currentId = daySession.currentNode?.id
        var secondsAhead: TimeInterval = 0

        for index in upcoming.indices {
            if index > 0 {
                let previous = upcoming[index - 1]
                if previous.id == currentId, let remaining = engine.remainingTime {
                    secondsAhead += remaining
                } else {
                    secondsAhead += duration(for: previous)
                }
            }
            let startDate = now.addingTimeInterval(secondsAhead)
            if startDate >= remindAt, let anchorIndex = allNodes.firstIndex(where: { $0.id == upcoming[index].id }) {
                return anchorIndex
            }
        }
        return allNodes.count
    }

    private func duration(for node: TimelineNode) -> TimeInterval {
        switch node.type {
        case .battle(let boss):
            return boss.maxHp
        case .bonfire(let duration):
            return duration
        case .treasure:
            return 0
        }
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

    private func makeFocusGroupNode(
        memberTemplateIds: [UUID],
        using cardStore: CardTemplateStore
    ) -> TimelineNode? {
        let templates = resolveTemplates(memberTemplateIds, using: cardStore)
        guard !templates.isEmpty else { return nil }
        
        let totalDuration = max(60, templates.reduce(0) { $0 + $1.defaultDuration })
        let category = templates.first?.category ?? .work
        let name: String
        if templates.count > 1 {
            name = templates.map(\.title).joined(separator: " + ")
        } else {
            name = templates.first?.title ?? "Focus Group"
        }
        let payload = FocusGroupPayload(
            memberTemplateIds: templates.map(\.id),
            activeIndex: 0
        )
        let boss = Boss(
            name: name,
            maxHp: totalDuration,
            style: .focus,
            category: category,
            templateId: nil,
            recommendedStart: nil,
            focusGroupPayload: payload
        )
        
        return TimelineNode(
            type: .battle(boss),
            isLocked: true,
            taskModeOverride: .focusGroupFlexible
        )
    }
    
    private func resolveTemplates(
        _ ids: [UUID],
        using cardStore: CardTemplateStore
    ) -> [CardTemplate] {
        var seen: Set<UUID> = []
        var templates: [CardTemplate] = []
        
        for id in ids {
            guard !seen.contains(id), let template = cardStore.get(id: id) else { continue }
            seen.insert(id)
            templates.append(template)
        }
        
        return templates
    }

}
