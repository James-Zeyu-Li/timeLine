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
    /// Allows moving any node, including the current selected node.
    /// Automatically tracks the new position of currentIndex after reordering.
    public func moveNode(from source: IndexSet, to destination: Int) {
        guard let movedIndex = source.first else { return }
        
        // Save the original currentIndex before moving
        let oldCurrentIndex = currentIndex
        
        // Perform the move
        nodes.move(fromOffsets: source, toOffset: destination)
        
        // Update currentIndex to track its new position
        if movedIndex == oldCurrentIndex {
            // The current node itself was moved
            // Calculate its new position based on the destination
            currentIndex = destination > movedIndex ? destination - 1 : destination
        } else {
            // A different node was moved, adjust currentIndex relatively
            if movedIndex < oldCurrentIndex && destination > oldCurrentIndex {
                // Moved from before to after currentIndex
                currentIndex -= 1
            } else if movedIndex > oldCurrentIndex && destination <= oldCurrentIndex {
                // Moved from after to before currentIndex
                currentIndex += 1
            }
        }
        
        // Critical: Re-evaluate lock states after reordering
        updateLockStates()
    }
    
    /// Updates lock states based on current rules.
    /// First position (Next Task), current task, and completed nodes are unlocked.
    private func updateLockStates() {
        for (index, _) in nodes.enumerated() {
            // Unlock: First position (always accessible as Next Task) 
            //         OR current task 
            //         OR completed tasks
            if index == 0 || index == currentIndex || nodes[index].isCompleted {
                nodes[index].isLocked = false
            } else {
                nodes[index].isLocked = true
            }
        }
    }

    /// Resets the current index to the first upcoming (not completed) node.
    /// Useful when reordering while no active session is running.
    public func resetCurrentToFirstUpcoming() {
        if let nextIndex = nodes.firstIndex(where: { !$0.isCompleted }) {
            currentIndex = nextIndex
        } else {
            currentIndex = nodes.count
        }
        updateLockStates()
    }
    
    /// Sets the current node by ID, unlocking it if necessary.
    public func setCurrentNode(id: UUID) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            currentIndex = index
            if nodes.indices.contains(index) {
                nodes[index].isLocked = false
            }
        }
    }
    // MARK: - Node Operations
    
    public func updateNode(id: UUID, payload: CardTemplate) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        
        var node = nodes[index]
        
        switch node.type {
        case .battle(var boss):
            boss.name = payload.title
            boss.maxHp = payload.defaultDuration
            boss.currentHp = boss.maxHp // Reset HP on edit
            boss.style = payload.style
            boss.category = payload.category
            
            node.type = .battle(boss)
            nodes[index] = node
            
        case .bonfire(_):
            // Update bonfire duration
            let newDuration = payload.defaultDuration
            node.type = .bonfire(newDuration)
            nodes[index] = node
            
        case .treasure:
            // Treasure nodes cannot be edited
            break
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
