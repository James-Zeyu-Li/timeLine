import Foundation

public enum TaskMode: String, Codable, Equatable {
    case focusStrictFixed
    case focusGroupFlexible
    case reminderOnly
}
