import Foundation

public struct RouteGenerator {
    
    /// Generates a "Dungeon Route" from a list of tasks.
    /// Inserts a Bonfire (15m) after every 2 Tasks.
    public static func generateRoute(from tasks: [Boss]) -> [TimelineNode] {
        var nodes: [TimelineNode] = []
        var consecutiveBattles = 0
        
        for (index, task) in tasks.enumerated() {
            // All nodes are locked initially except the first one
            let isLocked = (index != 0)
            
            let battleNode = TimelineNode(
                type: .battle(task),
                isLocked: isLocked
            )
            nodes.append(battleNode)
            
            consecutiveBattles += 1
            
            // Insert Bonfire every 2 battles, but not if it's the very last thing
            if consecutiveBattles == 2 && index < tasks.count - 1 {
                let bonfireNode = TimelineNode(
                    type: .bonfire(900), // 15 min rest
                    isLocked: true       // Bonfire is always locked initially
                )
                nodes.append(bonfireNode)
                consecutiveBattles = 0
            }
        }
        
        return nodes
    }
}
