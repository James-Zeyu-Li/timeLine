import SwiftUI
import Foundation

// MARK: - Shared Map Types

enum MapNodeAlignment {
    case left
    case right
}

struct MapTimeInfo {
    let absolute: String?
    let relative: String?
    let isRecommended: Bool
}

// MARK: - Preference Keys

struct MapNodeAnchorKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}