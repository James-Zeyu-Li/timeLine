import XCTest
@testable import TimeLineCore

final class QuickEntryTests: XCTestCase {
    
    func testBasicParsing() {
        let input = "Code 30m"
        guard let task = QuickEntryParser.parse(input: input) else {
            XCTFail("Should parse"); return
        }
        
        XCTAssertEqual(task.title, "Code")
        XCTAssertEqual(task.defaultDuration, 1800)
        XCTAssertEqual(task.style, .focus)
    }
    
    func testDurationFormats() {
        let cases = [
            ("Read 1h", 3600.0),
            ("Nap 1.5h", 5400.0),
            ("Short 10m", 600.0),
            ("Tiny 5min", 300.0)
        ]
        
        for (input, expectedSeconds) in cases {
            let task = QuickEntryParser.parse(input: input)!
            XCTAssertEqual(task.defaultDuration, expectedSeconds, "Failed for \(input)")
        }
    }
    
    func testTags() {
        let input = "Gym @gym @passive"
        let task = QuickEntryParser.parse(input: input)!
        
        XCTAssertEqual(task.title, "Gym")
        XCTAssertEqual(task.category, .gym)
        XCTAssertEqual(task.style, .passive)
    }
    
    func testDefaults() {
        let input = "Just Title"
        let task = QuickEntryParser.parse(input: input)!
        
        XCTAssertEqual(task.style, .focus)
        XCTAssertEqual(task.category, .work) // Default
        XCTAssertEqual(task.defaultDuration, 1500) // Default 25m
    }
    
    func testMixedOrder() {
        // Duration and tags mixed
        let input = "@study Review Notes 45m"
        let task = QuickEntryParser.parse(input: input)!
        
        XCTAssertEqual(task.title, "Review Notes")
        XCTAssertEqual(task.defaultDuration, 2700)
        XCTAssertEqual(task.category, .study)
    }
    
    func testEmptyInput() {
        XCTAssertNil(QuickEntryParser.parse(input: ""))
        XCTAssertNil(QuickEntryParser.parse(input: "   "))
        XCTAssertNil(QuickEntryParser.parse(input: "30m")) // No title -> invalid?
        // Actually my logic removes duration first. "30m" -> text becomes empty -> returns nil. Correct.
    }
}
