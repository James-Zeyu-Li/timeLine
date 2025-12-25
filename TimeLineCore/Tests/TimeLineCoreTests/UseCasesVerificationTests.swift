import XCTest
@testable import TimeLineCore

final class UseCasesVerificationTests: XCTestCase {
    
    // MARK: - Use Case 1: Quick Input
    
    func testQuickInput_Tonight() {
        // "Tonight write homework 1h" -> "今晚写作业 1h"
        // Target: Today list + Recommended Time 20:00
        
        let input = "今晚写作业 1h"
        guard let result = QuickEntryParser.parseDetailed(input: input) else {
            XCTFail("Parsing failed")
            return
        }
        
        // Check Title & Duration
        XCTAssertEqual(result.template.title, "写作业")
        XCTAssertEqual(result.template.duration, 3600) // 1h
        
        // Verify Placement (Today)
        XCTAssertEqual(result.placement, .today)
        
        // Verify Recommended Time (Tonight = 20:00 default)
        XCTAssertNotNil(result.suggestedTime)
        XCTAssertEqual(result.suggestedTime?.hour, 20)
        XCTAssertEqual(result.suggestedTime?.minute, 0)
    }
    
    func testQuickInput_TomorrowFitness() {
        // "Tomorrow fitness" -> "明天健身"
        // Target: Inbox
        
        let input = "明天健身"
        guard let result = QuickEntryParser.parseDetailed(input: input) else {
            XCTFail("Parsing failed")
            return
        }
        
        XCTAssertEqual(result.template.title, "健身")
        XCTAssertEqual(result.placement, .inbox)
        XCTAssertNil(result.suggestedTime)
    }
    
    func testQuickInput_DailyStretch() {
        // "Daily stretch" -> "每天拉伸"
        // Target: Template + Today Spawn
        
        let input = "每天拉伸"
        guard let result = QuickEntryParser.parseDetailed(input: input) else {
            XCTFail("Parsing failed")
            return
        }
        
        XCTAssertEqual(result.template.title, "拉伸")
        XCTAssertEqual(result.template.repeatRule, .daily)
    }
    
    // MARK: - Use Case 2: EventKit Placeholder
    
    func testEventKit_Placeholder_RecommendedStart() {
        // Logic: Read recommendedStart -> Write to Boss
        
        // 1. Simulate a Template that has a fixed time (representing a calendar gap for now)
        var components = DateComponents()
        components.hour = 14
        components.minute = 30
        
        let template = TaskTemplate(
            id: UUID(),
            title: "Meeting",
            duration: 1800,
            fixedTime: components,
            repeatRule: .none
        )
        
        // 2. Spawn Boss from Template
        let boss = SpawnManager.spawn(from: template)
        
        // 3. Verify Boss has recommendedStart set
        XCTAssertNotNil(boss.recommendedStart)
        XCTAssertEqual(boss.recommendedStart?.hour, 14)
        XCTAssertEqual(boss.recommendedStart?.minute, 30)
        
        // This confirms that IF we write to template/boss recommendedStart,
        // it persists on the model, which the UI reads to display "RECOMMENDED".
    }
}
