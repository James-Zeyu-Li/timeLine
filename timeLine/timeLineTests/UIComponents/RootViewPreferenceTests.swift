import XCTest
import SwiftUI
@testable import timeLine

final class RootViewPreferenceTests: XCTestCase {
    
    func testNodeFrameKeyMergesDictionaries() {
        let id1 = UUID()
        let id2 = UUID()
        let rect1 = CGRect(x: 10, y: 20, width: 30, height: 40)
        let rect2 = CGRect(x: 50, y: 60, width: 70, height: 80)
        
        var value: [UUID: CGRect] = [id1: rect1]
        NodeFrameKey.reduce(value: &value, nextValue: { [id2: rect2] })
        
        XCTAssertEqual(value[id1], rect1)
        XCTAssertEqual(value[id2], rect2)
    }
}
