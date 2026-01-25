import Foundation
#if os(iOS)
import ActivityKit

@available(iOS 26.0, *)
public struct FocusSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Start time is essential for the timer to display correctly
        public var startTime: Date
        
        // Target end time, if applicable (e.g. fixed focus)
        public var endTime: Date?
        
        // Current status description
        public var isPaused: Bool
        
        public init(startTime: Date, endTime: Date? = nil, isPaused: Bool = false) {
            self.startTime = startTime
            self.endTime = endTime
            self.isPaused = isPaused
        }
    }
    
    // Static data that doesn't change during the activity
    public var title: String
    public var modeName: String
    
    public init(title: String, modeName: String) {
        self.title = title
        self.modeName = modeName
    }
}
#endif
