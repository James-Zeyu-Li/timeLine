import XCTest
@testable import TimeLineCore

final class FocusGroupSessionCoordinatorTests: XCTestCase {
    func testAllocationsAccumulateAcrossSwitches() {
        let first = UUID()
        let second = UUID()
        let start = Date()
        let coordinator = FocusGroupSessionCoordinator(
            memberTemplateIds: [first, second],
            startTime: start
        )
        
        coordinator.recordFocused(seconds: 60)
        XCTAssertTrue(coordinator.switchTo(index: 1, at: start.addingTimeInterval(60)))
        coordinator.recordFocused(seconds: 60)
        XCTAssertTrue(coordinator.switchTo(index: 0, at: start.addingTimeInterval(120)))
        coordinator.recordFocused(seconds: 30)
        
        let summary = coordinator.endExploration(at: start.addingTimeInterval(150))
        XCTAssertEqual(summary.allocations[first] ?? 0, 90, accuracy: 0.1)
        XCTAssertEqual(summary.allocations[second] ?? 0, 60, accuracy: 0.1)
        XCTAssertEqual(summary.totalFocusedSeconds, 150, accuracy: 0.1)
        XCTAssertEqual(summary.segments.count, 3)
        XCTAssertEqual(summary.segments[0].templateId, first)
        XCTAssertEqual(summary.segments[0].duration, 60, accuracy: 0.1)
        XCTAssertEqual(summary.segments[1].templateId, second)
        XCTAssertEqual(summary.segments[1].duration, 60, accuracy: 0.1)
        XCTAssertEqual(summary.segments[2].templateId, first)
        XCTAssertEqual(summary.segments[2].duration, 30, accuracy: 0.1)
    }
    
    func testSwitchToIgnoresInvalidIndex() {
        let first = UUID()
        let start = Date()
        let coordinator = FocusGroupSessionCoordinator(
            memberTemplateIds: [first],
            startTime: start
        )
        
        XCTAssertFalse(coordinator.switchTo(index: 2, at: start.addingTimeInterval(10)))
        coordinator.recordFocused(seconds: 10)
        let summary = coordinator.endExploration(at: start.addingTimeInterval(10))
        XCTAssertEqual(summary.allocations[first] ?? 0, 10, accuracy: 0.1)
    }
}
