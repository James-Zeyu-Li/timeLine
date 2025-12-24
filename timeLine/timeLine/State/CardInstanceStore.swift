import SwiftUI
import Combine
import TimeLineCore

// MARK: - Card Instance Store

@MainActor
final class CardInstanceStore: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var instances: [UUID: CardInstance] = [:]
    @Published private(set) var handOrder: [UUID] = []  // front of array = front of fan
    
    // MARK: - CRUD
    
    func add(_ instance: CardInstance) {
        instances[instance.id] = instance
        handOrder.insert(instance.id, at: 0)  // new cards go to front
    }
    
    func update(_ instance: CardInstance) {
        instances[instance.id] = instance
    }
    
    func remove(id: UUID) {
        instances.removeValue(forKey: id)
        handOrder.removeAll { $0 == id }
    }
    
    func get(id: UUID) -> CardInstance? {
        instances[id]
    }
    
    // MARK: - Hand Management
    
    func seedDefaultsIfNeeded() {
        guard handOrder.isEmpty || instances.isEmpty else { return }
        let templates = DefaultCardTemplates.all
        for template in templates.reversed() {
            add(CardInstance.make(from: template))
        }
    }
    
    func cardsInHand() -> [CardInstance] {
        handOrder.compactMap { instances[$0] }
    }
    
    // MARK: - Placement
    
    func markPlaced(id: UUID, anchorNodeId: UUID) {
        guard var instance = instances[id] else { return }
        instance.anchorNodeId = anchorNodeId
        instance.status = .placed
        instances[id] = instance
        handOrder.removeAll { $0 == id }
    }
}
