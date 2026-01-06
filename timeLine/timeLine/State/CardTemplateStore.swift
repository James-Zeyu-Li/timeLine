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
    
    func orderedTemplates(includeEphemeral: Bool = true) -> [CardTemplate] {
        let ordered = order.compactMap { templates[$0] }
        guard !includeEphemeral else { return ordered }
        return ordered.filter { !$0.isEphemeral }
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

    struct Buckets {
        var deadline1: [LibraryEntry] = []
        var deadline3: [LibraryEntry] = []
        var deadline5: [LibraryEntry] = []
        var deadline7: [LibraryEntry] = []
        var later: [LibraryEntry] = []
        var expired: [LibraryEntry] = []
        var reminders: [LibraryEntry] = []
    }
    
    func add(templateId: UUID, addedAt: Date = Date()) {
        if entries[templateId] != nil {
            if !order.contains(templateId) {
                order.insert(templateId, at: 0)
            }
            return
        }
        
        let entry = LibraryEntry(
            templateId: templateId,
            addedAt: addedAt,
            deadlineStatus: .active
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
    
    func bucketedEntries(
        using cardStore: CardTemplateStore,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Buckets {
        let ordered = orderedEntries()
        var buckets = Buckets()
        var deadlineAtById: [UUID: Date] = [:]
        var remindAtById: [UUID: Date] = [:]

        for entry in ordered {
            guard let template = cardStore.get(id: entry.templateId) else { continue }

            if template.taskMode == .reminderOnly || template.remindAt != nil {
                if let remindAt = template.remindAt {
                    remindAtById[entry.templateId] = remindAt
                }
                buckets.reminders.append(entry)
                continue
            }

            if entry.deadlineStatus == .expired {
                buckets.expired.append(entry)
                continue
            }

            let usesExplicitDeadline = template.deadlineAt != nil
            if let deadlineAt = resolvedDeadlineAt(for: entry, template: template, calendar: calendar) {
                deadlineAtById[entry.templateId] = deadlineAt
                if now >= deadlineAt {
                    buckets.expired.append(entry)
                    continue
                }
                if usesExplicitDeadline {
                    let startNow = calendar.startOfDay(for: now)
                    let startDeadline = calendar.startOfDay(for: deadlineAt)
                    let dayDiff = calendar.dateComponents([.day], from: startNow, to: startDeadline).day ?? 0
                    switch dayDiff {
                    case ...0:
                        buckets.deadline1.append(entry)
                    case 1...3:
                        buckets.deadline3.append(entry)
                    case 4...7:
                        buckets.deadline7.append(entry)
                    default:
                        buckets.later.append(entry)
                    }
                } else if let windowDays = template.deadlineWindowDays {
                    switch windowDays {
                    case 1:
                        buckets.deadline1.append(entry)
                    case 3:
                        buckets.deadline3.append(entry)
                    case 5:
                        buckets.deadline5.append(entry)
                    case 7:
                        buckets.deadline7.append(entry)
                    default:
                        buckets.later.append(entry)
                    }
                } else {
                    buckets.later.append(entry)
                }
            } else {
                buckets.later.append(entry)
            }
        }

        sortDeadlineBucket(&buckets.deadline1, using: deadlineAtById)
        sortDeadlineBucket(&buckets.deadline3, using: deadlineAtById)
        sortDeadlineBucket(&buckets.deadline5, using: deadlineAtById)
        sortDeadlineBucket(&buckets.deadline7, using: deadlineAtById)
        buckets.reminders.sort { lhs, rhs in
            let lhsDate = remindAtById[lhs.templateId] ?? .distantFuture
            let rhsDate = remindAtById[rhs.templateId] ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.addedAt < rhs.addedAt
        }

        return buckets
    }
    
    func load(from entries: [LibraryEntry]) {
        self.entries = Dictionary(uniqueKeysWithValues: entries.map { ($0.templateId, $0) })
        self.order = entries.map(\.templateId)
    }
    
    func reset() {
        entries.removeAll()
        order.removeAll()
    }

    private func resolvedDeadlineAt(
        for entry: LibraryEntry,
        template: CardTemplate,
        calendar: Calendar
    ) -> Date? {
        if let deadlineAt = template.deadlineAt {
            return deadlineAt
        }
        guard let windowDays = template.deadlineWindowDays, windowDays > 0 else { return nil }
        return calendar.date(byAdding: .day, value: windowDays, to: entry.addedAt)
    }

    private func sortDeadlineBucket(_ bucket: inout [LibraryEntry], using deadlineAtById: [UUID: Date]) {
        bucket.sort { lhs, rhs in
            let lhsDate = deadlineAtById[lhs.templateId] ?? lhs.addedAt
            let rhsDate = deadlineAtById[rhs.templateId] ?? rhs.addedAt
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.addedAt < rhs.addedAt
        }
    }

    func refreshDeadlineStatuses(
        using cardStore: CardTemplateStore,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        var newlyExpired = 0
        var expiredIds: [UUID] = []
        for (id, entry) in entries {
            guard entry.deadlineStatus == .active else { continue }
            guard let template = cardStore.get(id: entry.templateId) else { continue }
            if template.taskMode == .reminderOnly || template.remindAt != nil {
                continue
            }
            guard let deadlineAt = resolvedDeadlineAt(for: entry, template: template, calendar: calendar) else { continue }
            if now >= deadlineAt {
                expiredIds.append(id)
            }
        }
        for id in expiredIds {
            guard var entry = entries[id] else { continue }
            entry.deadlineStatus = .expired
            entries[id] = entry
            newlyExpired += 1
        }
        return newlyExpired
    }
}
