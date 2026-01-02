import XCTest
@testable import TimeLineCore

final class RestPromptServiceTests: XCTestCase {
    func testEmitsSuggestionOnceAtThreshold() {
        let service = RestPromptService(thresholdSeconds: 100)
        XCTAssertNil(service.recordFocus(seconds: 40))
        XCTAssertNil(service.recordFocus(seconds: 59))
        let event = service.recordFocus(seconds: 1)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.thresholdSeconds, 100)
        XCTAssertEqual(event!.focusedSeconds, 100, accuracy: 0.01)
        XCTAssertNil(service.recordFocus(seconds: 10))
    }

    func testResetAfterContinueAllowsNewSuggestion() {
        let service = RestPromptService(thresholdSeconds: 60)
        _ = service.recordFocus(seconds: 60)
        XCTAssertNil(service.recordFocus(seconds: 10))
        service.resetAfterContinue()
        let event = service.recordFocus(seconds: 60)
        XCTAssertNotNil(event)
    }

    func testResetAfterRestClearsProgress() {
        let service = RestPromptService(thresholdSeconds: 30)
        _ = service.recordFocus(seconds: 20)
        service.resetAfterRest()
        XCTAssertNil(service.recordFocus(seconds: 20))
    }
}
