import XCTest
@testable import timeLine
import TimeLineCore

@MainActor
final class LibraryDeadlineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makeTemplate(id: UUID = UUID(), windowDays: Int?) -> CardTemplate {
        CardTemplate(
            id: id,
            title: "Task \(id.uuidString.prefix(4))",
            defaultDuration: 1800,
            deadlineWindowDays: windowDays
        )
    }

    func testBucketedEntries_UsesDeadlineWindowBuckets() {
        let now = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 9))!
        let cardStore = CardTemplateStore()
        let libraryStore = LibraryStore()

        let one = makeTemplate(windowDays: 1)
        let three = makeTemplate(windowDays: 3)
        let five = makeTemplate(windowDays: 5)
        let seven = makeTemplate(windowDays: 7)

        [one, three, five, seven].forEach { cardStore.add($0) }
        libraryStore.add(templateId: one.id, addedAt: now)
        libraryStore.add(templateId: three.id, addedAt: now)
        libraryStore.add(templateId: five.id, addedAt: now)
        libraryStore.add(templateId: seven.id, addedAt: now)

        let buckets = libraryStore.bucketedEntries(using: cardStore, now: now, calendar: calendar)

        XCTAssertEqual(buckets.deadline1.map(\.templateId), [one.id])
        XCTAssertEqual(buckets.deadline3.map(\.templateId), [three.id])
        XCTAssertEqual(buckets.deadline5.map(\.templateId), [five.id])
        XCTAssertEqual(buckets.deadline7.map(\.templateId), [seven.id])
    }

    func testBucketedEntries_SortsByDeadlineThenAddedAt() {
        let now = calendar.date(from: DateComponents(year: 2025, month: 1, day: 10, hour: 9))!
        let cardStore = CardTemplateStore()
        let libraryStore = LibraryStore()

        let olderId = UUID()
        let newerId = UUID()
        let olderTemplate = makeTemplate(id: olderId, windowDays: 3)
        let newerTemplate = makeTemplate(id: newerId, windowDays: 3)
        cardStore.add(olderTemplate)
        cardStore.add(newerTemplate)

        let olderAddedAt = calendar.date(byAdding: .day, value: -1, to: now)!
        libraryStore.add(templateId: newerId, addedAt: now)
        libraryStore.add(templateId: olderId, addedAt: olderAddedAt)

        let buckets = libraryStore.bucketedEntries(using: cardStore, now: now, calendar: calendar)
        XCTAssertEqual(buckets.deadline3.map(\.templateId), [olderId, newerId])
    }

    func testRefreshDeadlineStatuses_ExpiresOnce() {
        let now = calendar.date(from: DateComponents(year: 2025, month: 1, day: 10, hour: 9))!
        let cardStore = CardTemplateStore()
        let libraryStore = LibraryStore()

        let template = makeTemplate(windowDays: 1)
        cardStore.add(template)
        let addedAt = calendar.date(byAdding: .day, value: -2, to: now)!
        libraryStore.add(templateId: template.id, addedAt: addedAt)

        let first = libraryStore.refreshDeadlineStatuses(using: cardStore, now: now, calendar: calendar)
        XCTAssertEqual(first, 1)
        XCTAssertEqual(libraryStore.entry(for: template.id)?.deadlineStatus, .expired)

        let second = libraryStore.refreshDeadlineStatuses(using: cardStore, now: now, calendar: calendar)
        XCTAssertEqual(second, 0)

        let buckets = libraryStore.bucketedEntries(using: cardStore, now: now, calendar: calendar)
        XCTAssertEqual(buckets.expired.map(\.templateId), [template.id])
    }
}
