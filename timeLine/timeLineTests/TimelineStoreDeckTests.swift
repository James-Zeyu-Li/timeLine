import XCTest
@testable import TimeLineCore
@testable import timeLine

@MainActor
final class MockStateSaver: StateSaver {
    var saveRequested = false
    func requestSave() {
        saveRequested = true
    }
}

@MainActor
final class TimelineStoreDeckTests: XCTestCase {
    func testSanity() {
        // Test DaySession + TimelineStore + MockSaver
        let daySession = DaySession(nodes: [])
        let mockSaver = MockStateSaver()
        let timelineStore = TimelineStore(daySession: daySession, stateManager: mockSaver)
        
        XCTAssertNotNil(timelineStore)
        XCTAssertTrue(daySession.nodes.isEmpty)
    }
}
