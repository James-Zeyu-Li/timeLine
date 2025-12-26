import Foundation
import Combine
import TimeLineCore

@MainActor
final class CardTemplateStore: ObservableObject {
    @Published private(set) var templates: [UUID: CardTemplate] = [:]
    @Published private(set) var order: [UUID] = []
    
    func add(_ template: CardTemplate) {
        templates[template.id] = template
        if !order.contains(template.id) {
            order.insert(template.id, at: 0)
        }
    }
    
    func update(_ template: CardTemplate) {
        templates[template.id] = template
    }
    
    func remove(id: UUID) {
        templates.removeValue(forKey: id)
        order.removeAll { $0 == id }
    }
    
    func get(id: UUID) -> CardTemplate? {
        templates[id]
    }
    
    func orderedTemplates() -> [CardTemplate] {
        order.compactMap { templates[$0] }
    }
    
    func load(from templates: [CardTemplate]) {
        self.templates = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
        self.order = templates.map(\.id)
    }
    
    func reset() {
        templates.removeAll()
        order.removeAll()
    }
    
    func seedDefaultsIfNeeded() {
        guard order.isEmpty else { return }
        for template in DefaultCardTemplates.all.reversed() {
            add(template)
        }
    }
}
