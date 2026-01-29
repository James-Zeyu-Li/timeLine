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
    
    func markUsed(id: UUID, at date: Date = Date()) {
        guard var template = templates[id] else { return }
        template.lastActivatedAt = date
        templates[id] = template
        
        // Move to top of list as it is most recently used
        if let index = order.firstIndex(of: id) {
             order.remove(at: index)
        }
        order.insert(id, at: 0)
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

    enum LibraryTier: String, CaseIterable {
        case deadline1   // 1 day / daily repeats / urgent
        case deadline3   // 3 days
        case deadline10  // 10 days
        case deadline30  // 30+ days
        case noDeadline  // No deadline
        case frozen      // 7+ days inactive (auto-sink)
    }

    struct Buckets {
        var deadline1: [LibraryEntry] = []
        var deadline3: [LibraryEntry] = []
        var deadline10: [LibraryEntry] = []
        var deadline30: [LibraryEntry] = []
        var noDeadline: [LibraryEntry] = []
        var frozen: [LibraryEntry] = []
        var reminders: [LibraryEntry] = [] // Keep reminders separate
        var expired: [LibraryEntry] = []
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
        var sortDateById: [UUID: Date] = [:]
        var repeatPriorityById: [UUID: Bool] = [:]
        var remindAtById: [UUID: Date] = [:]

        for entry in ordered {
            guard let template = cardStore.get(id: entry.templateId) else { continue }

            // 1. Reminders (Separate)
            if template.taskMode == .reminderOnly || template.remindAt != nil {
                if let remindAt = template.remindAt {
                    remindAtById[entry.templateId] = remindAt
                }
                buckets.reminders.append(entry)
                continue
            }

            // 1.5 Expired tasks (separate)
            if entry.deadlineStatus == .expired {
                if let deadlineAt = resolvedDeadlineAt(for: entry, template: template, calendar: calendar) {
                    sortDateById[entry.templateId] = deadlineAt
                } else {
                    sortDateById[entry.templateId] = entry.addedAt
                }
                buckets.expired.append(entry)
                continue
            }
            
            // 2. Frozen (Staleness Check)
            // If lastActivatedAt is > 7 days ago, move to frozen
            if let lastActive = template.lastActivatedAt {
                let daysSinceActive = calendar.dateComponents([.day], from: lastActive, to: now).day ?? 0
                if daysSinceActive >= 7 {
                    buckets.frozen.append(entry)
                    sortDateById[entry.templateId] = lastActive
                    continue
                }
            } else {
                // If never activated, check creation date (entry.addedAt)
                // If added > 7 days ago and never touched, also frozen?
                // For now, let's only freeze if explicitly stale logic applied or simple age?
                // User said: "超过 7 天未激活的任务"
                let ageDays = calendar.dateComponents([.day], from: entry.addedAt, to: now).day ?? 0
                if ageDays >= 7 {
                    buckets.frozen.append(entry)
                    sortDateById[entry.templateId] = entry.addedAt
                    continue
                }
            }
            
            // 3. Urgency Bucketing (Today vs ShortTerm vs LongTerm)
            // "Today": deadline soon, or repeat rule matches today
            
            // Check Explicit Deadline
            var targetDate: Date? = nil
            if let deadlineAt = resolvedDeadlineAt(for: entry, template: template, calendar: calendar) {
                targetDate = deadlineAt
            }

            let repeatsToday = template.repeatRule.matches(date: now)
            if repeatsToday {
                repeatPriorityById[entry.templateId] = true
            }
            
            if let target = targetDate {
                sortDateById[entry.templateId] = target
                
                if now >= target {
                     // Overdue -> Treat as Urgent (1 day)
                    buckets.deadline1.append(entry)
                    continue
                }
                
                let startNow = calendar.startOfDay(for: now)
                let startTarget = calendar.startOfDay(for: target)
                let dayDiff = calendar.dateComponents([.day], from: startNow, to: startTarget).day ?? 0
                
                switch dayDiff {
                case ...1:
                    buckets.deadline1.append(entry)
                case 2...3:
                    buckets.deadline3.append(entry)
                case 4...10:
                    buckets.deadline10.append(entry)
                default:
                    buckets.deadline30.append(entry)
                }
            } else {
                // No deadline
                // Repeat rules that match today should bubble to 1-day bucket
                if repeatsToday {
                    buckets.deadline1.append(entry)
                    sortDateById[entry.templateId] = calendar.startOfDay(for: now)
                } else {
                    buckets.noDeadline.append(entry)
                    sortDateById[entry.templateId] = entry.addedAt
                }
            }
        }

        // Sort buckets
        sortBucket(&buckets.deadline1, using: sortDateById, repeatPriorityById: repeatPriorityById)
        sortBucket(&buckets.deadline3, using: sortDateById, repeatPriorityById: repeatPriorityById)
        sortBucket(&buckets.deadline10, using: sortDateById, repeatPriorityById: repeatPriorityById)
        sortBucket(&buckets.deadline30, using: sortDateById, repeatPriorityById: repeatPriorityById)
        sortBucket(&buckets.noDeadline, using: sortDateById, repeatPriorityById: repeatPriorityById)
        sortBucket(&buckets.frozen, using: sortDateById, repeatPriorityById: repeatPriorityById)
        sortBucket(&buckets.expired, using: sortDateById, repeatPriorityById: repeatPriorityById)
        
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

    private func sortBucket(
        _ bucket: inout [LibraryEntry],
        using dateMap: [UUID: Date],
        repeatPriorityById: [UUID: Bool]
    ) {
        bucket.sort { lhs, rhs in
            let lhsRepeat = repeatPriorityById[lhs.templateId] ?? false
            let rhsRepeat = repeatPriorityById[rhs.templateId] ?? false
            if lhsRepeat != rhsRepeat {
                return lhsRepeat && !rhsRepeat
            }
            let lhsDate = dateMap[lhs.templateId] ?? lhs.addedAt
            let rhsDate = dateMap[rhs.templateId] ?? rhs.addedAt
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
