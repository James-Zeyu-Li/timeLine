import XCTest
@testable import timeLine
import TimeLineCore

@MainActor
final class PlanDomainTests: XCTestCase {
    
    var daySession: DaySession!
    var stateManager: MockStateSaver!
    var timelineStore: TimelineStore!
    var viewModel: PlanViewModel!
    var cardStore: CardTemplateStore!
    
    override func setUp() async throws {
        daySession = DaySession(nodes: [])
        stateManager = MockStateSaver()
        timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        cardStore = CardTemplateStore()
        
        viewModel = PlanViewModel()
        viewModel.configure(timelineStore: timelineStore, cardStore: cardStore)
    }
    
    // Test 1: Parse -> Stage
    func testParseAndStage_AddsToStagedTemplates() {
        // Given
        viewModel.draftText = "Coding 45m"
        
        // When
        viewModel.parseAndStage()
        
        // Then
        XCTAssertEqual(viewModel.stagedTemplates.count, 1)
        
        let template = viewModel.stagedTemplates.first!
        XCTAssertEqual(template.template.title, "Coding")
        XCTAssertEqual(template.template.defaultDuration, 45 * 60)
        XCTAssertTrue(template.template.isEphemeral)
        
        XCTAssertTrue(viewModel.draftText.isEmpty)
    }
    
    // Test 2: Commit -> Timeline (Inbox)
    func testCommitToTimeline_MovesStagedToInbox() {
        // Given
        viewModel.draftText = "Task A"
        viewModel.parseAndStage()
        
        viewModel.draftText = "Task B"
        viewModel.parseAndStage()
        
        XCTAssertEqual(viewModel.stagedTemplates.count, 2)
        
        // When
        let expectation = XCTestExpectation(description: "Dismiss")
        viewModel.commitToTimeline { expectation.fulfill() }
        
        // Then
        // 1. Staging cleared
        XCTAssertEqual(viewModel.stagedTemplates.count, 0)
        
        // 2. Added to Inbox
        XCTAssertEqual(timelineStore.inbox.count, 2)
        
        let firstNode = timelineStore.inbox[0]
        let secondNode = timelineStore.inbox[1]
        
        // Check order (should be appended)
        guard case .battle(let bossA) = firstNode.type,
              case .battle(let bossB) = secondNode.type else {
            XCTFail("Nodes should be battle")
            return
        }
        
        XCTAssertEqual(bossA.name, "Task A")
        XCTAssertEqual(bossB.name, "Task B")
        
        XCTAssertTrue(firstNode.isUnscheduled)
        
        wait(for: [expectation], timeout: 0.1)
    }
    
    // Test 3: Quick Access -> Stage
    func testQuickAccess_StagesClone() {
        // Given
        let template = CardTemplate(title: "Recurring", defaultDuration: 300)
        
        // When
        viewModel.stageQuickAccessTask(template)
        
        // Then
        XCTAssertEqual(viewModel.stagedTemplates.count, 1)
        let staged = viewModel.stagedTemplates.first!
        
        XCTAssertEqual(staged.template.title, "Recurring")
        XCTAssertNotEqual(staged.template.id, template.id, "Should clone ID") 
        XCTAssertTrue(staged.template.isEphemeral)
    }
}
