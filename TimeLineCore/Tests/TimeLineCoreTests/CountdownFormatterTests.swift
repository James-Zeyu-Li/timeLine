import XCTest
@testable import TimeLineCore

final class CountdownFormatterTests: XCTestCase {
    func testFormatRelativeHandlesSecondsAndMinutes() {
        XCTAssertNil(CountdownFormatter.formatRelative(seconds: 0))
        XCTAssertEqual(CountdownFormatter.formatRelative(seconds: 59), "in 59s")
        XCTAssertEqual(CountdownFormatter.formatRelative(seconds: 60), "in 1m")
    }

    func testFormatRelativeHandlesHours() {
        XCTAssertEqual(CountdownFormatter.formatRelative(seconds: 3600), "in 1h")
        XCTAssertEqual(CountdownFormatter.formatRelative(seconds: 3660), "in 1h 1m")
    }

    func testFormatRemainingOmitsPrefix() {
        XCTAssertNil(CountdownFormatter.formatRemaining(seconds: 0))
        XCTAssertEqual(CountdownFormatter.formatRemaining(seconds: 45), "45s")
        XCTAssertEqual(CountdownFormatter.formatRemaining(seconds: 75), "1m")
    }
}
