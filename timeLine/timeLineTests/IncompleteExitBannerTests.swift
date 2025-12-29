import XCTest
import Combine
@testable import timeLine

@MainActor
final class IncompleteExitBannerTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        throw XCTSkip("Skipped: simulator crash (AddressSanitizer bad-free in libswift_Concurrency).")
    }

    func testCoordinatorEmitsIncompleteExitEvent() {
        let engine = BattleEngine()
        let boss = Boss(name: "Focus Task", maxHp: 600)
        let nextBoss = Boss(name: "Next Task", maxHp: 300)
        let daySession = DaySession(nodes: [
            TimelineNode(type: .battle(boss), isLocked: false),
            TimelineNode(type: .battle(nextBoss), isLocked: true)
        ])
        let stateManager = MockStateSaver()
        let coordinator = TimelineEventCoordinator(
            engine: engine,
            daySession: daySession,
            stateManager: stateManager
        )
        
        let expectation = XCTestExpectation(description: "Incomplete exit emits event")
        var cancellables = Set<AnyCancellable>()
        
        coordinator.uiEvents
            .sink { event in
                guard case .incompleteExit(_, let focusedSeconds, let remainingSeconds) = event else { return }
                XCTAssertEqual(focusedSeconds, 120, accuracy: 0.1)
                XCTAssertEqual(remainingSeconds ?? 0, 480, accuracy: 0.1)
                XCTAssertEqual(daySession.currentIndex, 1)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        let startTime = Date()
        engine.startBattle(boss: boss, at: startTime)
        let retreatTime = startTime.addingTimeInterval(120)
        engine.tick(at: retreatTime)
        engine.retreat(at: retreatTime)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMapViewModelBuildsIncompleteExitBanner() {
        let boss = Boss(name: "Focus Task", maxHp: 600)
        let nextBoss = Boss(name: "Next Task", maxHp: 300)
        let daySession = DaySession(nodes: [
            TimelineNode(type: .battle(boss), isLocked: false),
            TimelineNode(type: .battle(nextBoss), isLocked: true)
        ])
        let viewModel = MapViewModel(allowsPulseClear: false)
        viewModel.bind(
            engine: BattleEngine(),
            daySession: daySession,
            use24HourClock: true
        )
        
        viewModel.handleUIEvent(.incompleteExit(
            taskName: boss.name,
            focusedSeconds: 120,
            remainingSeconds: 480
        ))
        
        guard let banner = viewModel.banner else {
            XCTFail("Expected banner to be set")
            return
        }
        guard case .incompleteExit(let focusedSeconds, let remainingSeconds) = banner.kind else {
            XCTFail("Expected incompleteExit banner")
            return
        }
        XCTAssertEqual(focusedSeconds, 120, accuracy: 0.1)
        XCTAssertEqual(remainingSeconds ?? 0, 480, accuracy: 0.1)
    }
}
