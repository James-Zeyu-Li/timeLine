import Foundation

public class DaySession: ObservableObject, Codable {
    @Published public var nodes: [TimelineNode]
    @Published public var currentIndex: Int
    
    public init(nodes: [TimelineNode], currentIndex: Int = 0) {
        self.nodes = nodes
        self.currentIndex = currentIndex
    }
    
    // Codable conformance for @Published properties
    enum CodingKeys: CodingKey {
        case nodes
        case currentIndex
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nodes = try container.decode([TimelineNode].self, forKey: .nodes)
        self.currentIndex = try container.decode(Int.self, forKey: .currentIndex)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(currentIndex, forKey: .currentIndex)
    }
    
    public var currentNode: TimelineNode? {
        guard nodes.indices.contains(currentIndex) else { return nil }
        return nodes[currentIndex]
    }
    
    public var isFinished: Bool {
        return currentIndex >= nodes.count
    }
    
    public var completionProgress: Double {
        guard !nodes.isEmpty else { return 0 }
        let completedCount = nodes.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(nodes.count)
    }
    
    public func advance() {
        guard !isFinished else { return }
        
        // Mark current as complete
        nodes[currentIndex].isCompleted = true
        
        // Move to next
        currentIndex += 1
        
        // Unlock next if available
        if nodes.indices.contains(currentIndex) {
            nodes[currentIndex].isLocked = false
        }
    }
    
    public func loadRoutine(_ template: RoutineTemplate) {
        // Clear all nodes and reset index
        // This is legacy behavior. We will keep it but `appendRoutine` is preferred for V1.
        
        var newNodes: [TimelineNode] = []
        
        for (index, preset) in template.presets.enumerated() {
            let boss = Boss(name: preset.title, maxHp: preset.duration, style: preset.style)
            let node = TimelineNode(type: .battle(boss), isLocked: index > 0)
            newNodes.append(node)
        }
        
        self.nodes = newNodes
        self.currentIndex = 0
    }
    
    public func appendRoutine(_ template: RoutineTemplate) {
        // Determine if we should lock new nodes. 
        // If the timeline is finished or empty, the first new node should be unlocked.
        // If we are in the middle of a timeline, all new nodes should be locked (until we reach them).
        
        let shouldUnlockFirst = nodes.isEmpty || isFinished
        
        var newNodes: [TimelineNode] = []
        
        for (index, preset) in template.presets.enumerated() {
            let boss = Boss(name: preset.title, maxHp: preset.duration, style: preset.style)
            // First node unlocks if appropriate, others are locked
            let isLocked = (index == 0) ? !shouldUnlockFirst : true
            
            let node = TimelineNode(type: .battle(boss), isLocked: isLocked)
            newNodes.append(node)
        }
        
        self.nodes.append(contentsOf: newNodes)
        // Note: currentIndex stays where it is, allowing seamless continuation.
    }
}
