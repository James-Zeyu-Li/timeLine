import Foundation
@testable import timeLine

@MainActor
final class MockStateSaver: StateSaver {
    private(set) var saveRequested = false
    
    func requestSave() {
        saveRequested = true
    }
    
    func reset() {
        saveRequested = false
    }
}
