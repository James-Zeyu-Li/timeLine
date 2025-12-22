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
    
    /// Move node from one position to another (for drag-to-reorder).
    /// Only allows moving nodes that are NOT the current active node.
    public func moveNode(from source: IndexSet, to destination: Int) {
        // Safety: Don't allow moving the current active node
        guard !source.contains(currentIndex) else { return }
        
        nodes.move(fromOffsets: source, toOffset: destination)
        
        // Recalculate currentIndex if it was affected
        if let first = source.first {
            if first < currentIndex && destination > currentIndex {
                currentIndex -= 1
            } else if first > currentIndex && destination <= currentIndex {
                currentIndex += 1
            }
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
        // 1. Convert presets to Boss objects
        let bosses = template.presets.map { preset in
            Boss(name: preset.title, maxHp: preset.duration, style: preset.style, category: preset.category)
        }
        
        // 2. Generate route (Auto-inserts Bonfires)
        var newNodes = RouteGenerator.generateRoute(from: bosses)
        
        // 3. Normalize: Force all new nodes to be locked/pending initially
        for i in 0..<newNodes.count {
            newNodes[i].isLocked = true
            newNodes[i].isCompleted = false
        }
        
        // 4. Append to timeline
        let oldNodeCount = nodes.count
        self.nodes.append(contentsOf: newNodes)
        
        // 5. Activation Rule:
        // If the timeline was empty or finished before appending, we must activate the first new node.
        // Otherwise (mid-run), do nothing. they await their turn.
        
        let shouldActivateFirst = (oldNodeCount == 0) || isFinished
        
        if shouldActivateFirst && !newNodes.isEmpty {
            // Unlock the first *new* node. 
            // Note: RouteGenerator might put a locked Bonfire somewhere, but node[0] is usually the task.
            // We unlock nodes[oldNodeCount] which is the start of the new batch.
            nodes[oldNodeCount].isLocked = false
        }
    }
    
    // MARK: - Node Operations
    
    public func updateNode(id: UUID, payload: TaskTemplate) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        
        var node = nodes[index]
        
        // We only support updating Battle nodes for now
        if case .battle(var boss) = node.type {
            boss.name = payload.title
            boss.maxHp = payload.duration ?? 1800 // Fallback if nil, though focus tasks should have duration
            boss.currentHp = boss.maxHp // Reset HP on edit? Or scale? V1: Reset.
            boss.style = payload.style
            boss.category = payload.category
            
            node.type = .battle(boss)
            nodes[index] = node
        }
    }
    
    public func deleteNode(id: UUID) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        
        // Safety: If deleting the Active node
        if index == currentIndex {
            // Option 1: Advance to next immediately
            // Option 2: Retract index if possible?
            // Decision: Advance (Mark complete? No, just delete)
            // If we delete the active node, the next one (index+1) becomes active at index.
            // But if we just remove it, the array shifts.
            
            // Example: [A, B, C], index=1 (B). Delete B -> [A, C]. index=1 (C). C becomes active.
            // We must unlock C.
            
            nodes.remove(at: index)
            if nodes.indices.contains(currentIndex) {
                nodes[currentIndex].isLocked = false
            }
        } else if index < currentIndex {
            // Deleting a past node
            nodes.remove(at: index)
            currentIndex -= 1
        } else {
            // Deleting a future node
            nodes.remove(at: index)
        }
    }
    
    public func duplicateNode(id: UUID) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        
        let original = nodes[index]
        let newId = UUID()
        
        // We can't modify 'let id'. Wait, TimelineNode.id is let.
        // We need to construct a new TimelineNode.
        
        var newType = original.type
        if case .battle(let boss) = original.type {
            let newBoss = Boss(
                name: boss.name,
                maxHp: boss.maxHp,
                style: boss.style,
                category: boss.category,
                templateId: boss.templateId
            )
            newType = .battle(newBoss)
        }
        
        let duplicate = TimelineNode(
            id: newId,
            type: newType,
            isCompleted: false, // Provide fresh state
            isLocked: true     // Always locked initially
        )
        
        // Insert after original
        nodes.insert(duplicate, at: index + 1)
        
        // If we duplicated the active node, the active one remains active. The new one is next and locked.
    }
}
