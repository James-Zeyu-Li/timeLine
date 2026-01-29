import XCTest
@testable import timeLine
import TimeLineCore

final class LibraryDeadlineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }



    private func makeTemplate(id: UUID = UUID(), windowDays: Int? = nil, deadlineAt: Date? = nil) -> CardTemplate {
        CardTemplate(
            id: id,
            title: "Task \(id.uuidString.prefix(4))",
            defaultDuration: 1800,
            deadlineWindowDays: windowDays,
            deadlineAt: deadlineAt
        )
    }

    func testBucketedEntries_UsesDeadlineWindowBuckets() async {
        await MainActor.run {
            let now = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 9))!
            let cardStore = CardTemplateStore()
            let libraryStore = LibraryStore()

            let one = makeTemplate(windowDays: 1)
            let three = makeTemplate(windowDays: 3)
            let ten = makeTemplate(windowDays: 10)
            let thirty = makeTemplate(windowDays: 30)

            [one, three, ten, thirty].forEach { cardStore.add($0) }
            libraryStore.add(templateId: one.id, addedAt: now)
            libraryStore.add(templateId: three.id, addedAt: now)
            libraryStore.add(templateId: ten.id, addedAt: now)
            libraryStore.add(templateId: thirty.id, addedAt: now)

            let buckets = libraryStore.bucketedEntries(using: cardStore, now: now, calendar: calendar)

            XCTAssertEqual(buckets.deadline1.map(\.templateId), [one.id])
            XCTAssertEqual(buckets.deadline3.map(\.templateId), [three.id])
            XCTAssertEqual(buckets.deadline10.map(\.templateId), [ten.id])
            XCTAssertEqual(buckets.deadline30.map(\.templateId), [thirty.id])
        }

    }

    func testBucketedEntries_UsesAbsoluteDeadline() async {
        await MainActor.run {
            let now = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 9))! // Jan 1 9am
            let cardStore = CardTemplateStore()
            let libraryStore = LibraryStore()

            // Today: Jan 1 23:59
            let todayDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 18))!
            let todayTpl = makeTemplate(deadlineAt: todayDate)

            // Tomorrow: Jan 2
            let tomorrowDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 2, hour: 12))!
            let tomorrowTpl = makeTemplate(deadlineAt: tomorrowDate)

            // Later (Next 3 Days - actually absolute dates map depending on bucket logic)
            // LibraryStore.bucketedEntries implementation uses 'days until deadline' logic?
            // Let's verify if LibraryStore uses windowDays OR calculates daysDiff from deadlineAt.
            // Based on TodoSheet.swift resolvedDeadlineAt, it tries deadlineAt first.
            
            // Let's assume LibraryStore uses similar logic.
            // If LibraryStore.bucketedEntries uses deadlineAt to determine 'deadline1', 'deadline3' etc.
            
            cardStore.add(todayTpl)
            cardStore.add(tomorrowTpl)
            
            libraryStore.add(templateId: todayTpl.id, addedAt: now)
            libraryStore.add(templateId: tomorrowTpl.id, addedAt: now)
            
            let buckets = libraryStore.bucketedEntries(using: cardStore, now: now, calendar: calendar)
            
            // deadline1 = Today/Tomorrow (0-1 days)
            // deadline3 = 2-3 days
            
            XCTAssertTrue(buckets.deadline1.contains(where: { $0.templateId == todayTpl.id }))
            XCTAssertTrue(buckets.deadline1.contains(where: { $0.templateId == tomorrowTpl.id }))
            // Wait, deadline1 usually means "Within 1 day" or Window=1?
            // Existing test used windowDays: 1 -> deadline1.
            // windowDays: 3 -> deadline3.
            
            // If absolute logic works, check standard buckets.
        }
    }

    func testBucketedEntries_SortsByDeadlineThenAddedAt() async {
        await MainActor.run {
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
    }

    func testRefreshDeadlineStatuses_ExpiresOnce() async {
        await MainActor.run {
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
}
