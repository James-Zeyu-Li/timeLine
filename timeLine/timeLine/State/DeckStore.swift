import Foundation
import Combine
import TimeLineCore

struct DeckTemplate: Identifiable, Equatable {
    let id: UUID
    var title: String
    var cardTemplateIds: [UUID]
    
    var count: Int { cardTemplateIds.count }
    
    init(id: UUID = UUID(), title: String, cardTemplateIds: [UUID]) {
        self.id = id
        self.title = title
        self.cardTemplateIds = cardTemplateIds
    }
}

@MainActor
final class DeckStore: ObservableObject {
    @Published private(set) var decks: [UUID: DeckTemplate] = [:]
    @Published private(set) var order: [UUID] = []
    
    func add(_ deck: DeckTemplate) {
        decks[deck.id] = deck
        if !order.contains(deck.id) {
            order.insert(deck.id, at: 0)
        }
    }
    
    func update(_ deck: DeckTemplate) {
        decks[deck.id] = deck
    }
    
    func remove(id: UUID) {
        decks.removeValue(forKey: id)
        order.removeAll { $0 == id }
    }
    
    func get(id: UUID) -> DeckTemplate? {
        decks[id]
    }
    
    func orderedDecks() -> [DeckTemplate] {
        order.compactMap { decks[$0] }
    }
    
    func seedDefaultsIfNeeded(using cardStore: CardTemplateStore) {
        guard order.isEmpty else { return }
        let email = DefaultCardTemplates.email
        let coding = DefaultCardTemplates.coding
        cardStore.add(email)
        cardStore.add(coding)
        let focusSprint = DeckTemplate(
            title: "Focus Sprint",
            cardTemplateIds: [email.id, coding.id]
        )
        add(focusSprint)
    }
    
    func addDeck(from routine: RoutineTemplate, using cardStore: CardTemplateStore) {
        let templates = routine.presets.map { preset in
            CardTemplate(
                title: preset.title,
                icon: preset.style == .focus ? "bolt.fill" : "sparkles",
                defaultDuration: preset.duration,
                tags: [],
                energyColor: energyToken(for: preset.category),
                category: preset.category,
                style: preset.style
            )
        }
        templates.forEach { cardStore.add($0) }
        let deck = DeckTemplate(
            title: routine.name,
            cardTemplateIds: templates.map(\.id)
        )
        add(deck)
    }
    
    func totalDuration(for deck: DeckTemplate, using cardStore: CardTemplateStore) -> TimeInterval {
        deck.cardTemplateIds.compactMap { cardStore.get(id: $0)?.defaultDuration }.reduce(0, +)
    }
    
    private func energyToken(for category: TaskCategory) -> EnergyColorToken {
        switch category {
        case .work, .study:
            return .focus
        case .gym:
            return .gym
        case .rest:
            return .rest
        case .other:
            return .creative
        }
    }
}
