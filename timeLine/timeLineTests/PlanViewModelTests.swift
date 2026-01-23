import XCTest
import Combine
@testable import timeLine
@testable import TimeLineCore

@MainActor
final class PlanViewModelTests: XCTestCase {
    
    var viewModel: PlanViewModel!
    var timelineStore: TimelineStore!
    var cardStore: CardTemplateStore!
    
    override func setUp() async throws {
        // Create test stores
        let daySession = DaySession(nodes: [])
        let stateManager = MockStateSaver()
        timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        cardStore = CardTemplateStore()
        
        viewModel = PlanViewModel()
        viewModel.configure(timelineStore: timelineStore, cardStore: cardStore)
    }
    
    // MARK: - Parsing Tests
    
    func testParseAndStage_parsesDurationCorrectly() {
        // Given
        viewModel.draftText = "Study Physics 45m"
        
        // When
        viewModel.parseAndStage()
        
        // Then
        XCTAssertEqual(viewModel.stagedTemplates.count, 1)
        let staged = viewModel.stagedTemplates.first!
        XCTAssertEqual(staged.template.title, "Study Physics")
        XCTAssertEqual(staged.template.defaultDuration, 45 * 60)
        XCTAssertTrue(staged.template.isEphemeral)
        XCTAssertTrue(viewModel.draftText.isEmpty)
    }
    
    func testParseAndStage_usesDefaultDuration_whenMissing() {
        // Given
        viewModel.draftText = "Quick Task"
        
        // When
        viewModel.parseAndStage()
        
        // Then
        let staged = viewModel.stagedTemplates.first!
        XCTAssertEqual(staged.template.title, "Quick Task")
        XCTAssertEqual(staged.template.defaultDuration, 25 * 60) // Default 25m
    }
    
    // MARK: - Staging Tests
    
    func testRemoveStagedTask() {
        // Given
        viewModel.draftText = "Task A"
        viewModel.parseAndStage()
        let id = viewModel.stagedTemplates.first!.id
        
        // When
        viewModel.removeStagedTask(id: id)
        
        // Then
        XCTAssertTrue(viewModel.stagedTemplates.isEmpty)
    }
    
    // MARK: - Quick Access Tests
    
    func testStageQuickAccessTask_clonesTemplate() {
        // Given
        let original = CardTemplate.mock(title: "Frequent", duration: 100, color: .focus)
        
        // When
        viewModel.stageQuickAccessTask(original)
        
        // Then
        XCTAssertEqual(viewModel.stagedTemplates.count, 1)
        let staged = viewModel.stagedTemplates.first!
        
        XCTAssertEqual(staged.template.title, original.title)
        XCTAssertEqual(staged.template.defaultDuration, original.defaultDuration)
        XCTAssertNotEqual(staged.template.id, original.id, "Should create a new ID/Clone")
        XCTAssertTrue(staged.template.isEphemeral, "Staged task should be ephemeral")
    }
    
    // MARK: - Integration Mock Test
    // (Testing commitToTimeline logic would typically verify the store calls, 
    // but TimelineStore.placeholder might not persist in a verifiable way purely here 
    // without a proper spy. We trust TimelineStore's own tests for placement.)
}
