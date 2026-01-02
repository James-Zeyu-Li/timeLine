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

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var entries: [UUID: LibraryEntry] = [:]
    @Published private(set) var order: [UUID] = []
    
    func add(templateId: UUID, deadline: Date? = nil, addedAt: Date = Date()) {
        if var existing = entries[templateId] {
            if let deadline {
                existing.deadline = deadline
                entries[templateId] = existing
            }
            if !order.contains(templateId) {
                order.insert(templateId, at: 0)
            }
            return
        }
        
        let entry = LibraryEntry(
            templateId: templateId,
            addedAt: addedAt,
            deadline: deadline
        )
        entries[templateId] = entry
        order.insert(templateId, at: 0)
    }
    
    func upsert(_ entry: LibraryEntry) {
        entries[entry.templateId] = entry
        if !order.contains(entry.templateId) {
            order.insert(entry.templateId, at: 0)
        }
    }
    
    func remove(templateId: UUID) {
        entries.removeValue(forKey: templateId)
        order.removeAll { $0 == templateId }
    }
    
    func entry(for templateId: UUID) -> LibraryEntry? {
        entries[templateId]
    }
    
    func orderedEntries() -> [LibraryEntry] {
        order.compactMap { entries[$0] }
    }
    
    func groupedEntries(using cardStore: CardTemplateStore) -> (pinned: [LibraryEntry], others: [LibraryEntry]) {
        let ordered = orderedEntries()
        var pinned: [LibraryEntry] = []
        var others: [LibraryEntry] = []
        
        for entry in ordered {
            let hasDeadline = entry.deadline != nil
            let hasRepeat = (cardStore.get(id: entry.templateId)?.repeatRule ?? .none) != .none
            if hasDeadline || hasRepeat {
                pinned.append(entry)
            } else {
                others.append(entry)
            }
        }
        
        return (pinned, others)
    }
    
    func load(from entries: [LibraryEntry]) {
        self.entries = Dictionary(uniqueKeysWithValues: entries.map { ($0.templateId, $0) })
        self.order = entries.map(\.templateId)
    }
    
    func reset() {
        entries.removeAll()
        order.removeAll()
    }
}
