import Foundation

/// Generates a timeline route with automatic rest breaks (Bonfires) between tasks.
/// Follows the Pomodoro-inspired principle: work sessions followed by mandatory rest.
public struct RouteGenerator {
    
    // MARK: - Configuration
    
    /// Default rest duration between tasks (in seconds)
    public static let defaultRestDuration: TimeInterval = 900 // 15 minutes
    
    /// Number of consecutive battles before inserting a rest break
    public static let battlesBeforeRest: Int = 2
    
    // MARK: - Route Generation
    
    /// Generates a "Journey Route" from a list of tasks with automatic rest breaks.
    /// 
    /// Bonfire nodes (rest periods) are automatically inserted after every `battlesBeforeRest` tasks
    /// to enforce healthy work-rest rhythm. This follows productivity research suggesting
    /// regular breaks improve focus and prevent burnout.
    /// 
    /// - Parameter tasks: Array of Boss objects representing focus tasks
    /// - Returns: Array of TimelineNode with battles and interspersed bonfires
    public static func generateRoute(from tasks: [Boss]) -> [TimelineNode] {
        var nodes: [TimelineNode] = []
        var consecutiveBattles = 0
        
        for (index, task) in tasks.enumerated() {
            // First node is unlocked, all others locked until reached
            let isLocked = (index != 0)
            
            let battleNode = TimelineNode(
                type: .battle(task),
                isLocked: isLocked
            )
            nodes.append(battleNode)
            
            consecutiveBattles += 1
            
            // Insert mandatory rest break after N battles (but not after the last task)
            let shouldInsertRest = consecutiveBattles >= battlesBeforeRest && index < tasks.count - 1
            
            if shouldInsertRest {
                let bonfireNode = TimelineNode(
                    type: .bonfire(defaultRestDuration),
                    isLocked: true  // Unlocked automatically when previous task completes
                )
                nodes.append(bonfireNode)
                consecutiveBattles = 0
            }
        }
        
        return nodes
    }
    
    /// Generates a route with custom rest duration
    public static func generateRoute(from tasks: [Boss], restDuration: TimeInterval) -> [TimelineNode] {
        var nodes: [TimelineNode] = []
        var consecutiveBattles = 0
        
        for (index, task) in tasks.enumerated() {
            let isLocked = (index != 0)
            
            let battleNode = TimelineNode(
                type: .battle(task),
                isLocked: isLocked
            )
            nodes.append(battleNode)
            
            consecutiveBattles += 1
            
            if consecutiveBattles >= battlesBeforeRest && index < tasks.count - 1 {
                let bonfireNode = TimelineNode(
                    type: .bonfire(restDuration),
                    isLocked: true
                )
                nodes.append(bonfireNode)
                consecutiveBattles = 0
            }
        }
        
        return nodes
    }
}
