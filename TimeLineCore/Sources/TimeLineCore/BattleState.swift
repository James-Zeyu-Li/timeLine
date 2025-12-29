import Foundation

public enum BattleState: String, Equatable, Codable {
    case idle
    case fighting
    case paused
    case frozen
    case victory
    case retreat
    case resting
}
