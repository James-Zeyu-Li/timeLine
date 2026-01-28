import SwiftUI
import Combine
import TimeLineCore

// MARK: - Drop Action

enum DropAction: Equatable {
    case placeCard(cardTemplateId: UUID, anchorNodeId: UUID, placement: DropPlacement)
    case placeDeck(deckId: UUID, anchorNodeId: UUID, placement: DropPlacement)
    case placeFocusGroup(memberTemplateIds: [UUID], anchorNodeId: UUID, placement: DropPlacement)
    case moveNode(nodeId: UUID, anchorNodeId: UUID, placement: DropPlacement)
    case cancel
}

enum DropPlacement: Equatable {
    case before
    case after
}

enum DropAxisDirection {
    case topToBottom
    case bottomToTop
}

struct DeckDragSummary: Equatable {
    let count: Int
    let duration: TimeInterval
}

// MARK: - Drag Drop Coordinator

@MainActor
final class DragDropCoordinator: ObservableObject {
    
    // MARK: - Published State
    
    @Published var dragLocation: CGPoint = .zero
    @Published var dragOffset: CGSize = .zero
    @Published var hoveringNodeId: UUID?
    @Published var activeDeckSummary: DeckDragSummary?
    @Published var hoveringPlacement: DropPlacement = .after
    @Published var initialDragLocation: CGPoint? // Captured when drag mode starts
    @Published var isDragEnded = false // Signal to RootView that drag gesture ended
    
    // MARK: - Internal State
    
    private(set) var activePayload: DragPayload?
    private var axisDirection: DropAxisDirection = .bottomToTop
    
    // MARK: - Computed Properties
    
    var draggedNodeId: UUID? {
        guard let payload = activePayload else { return nil }
        if case .node(let nodeId) = payload.type {
            return nodeId
        }
        return nil
    }
    
    var isDragging: Bool {
        activePayload != nil
    }
    
    func destinationIndex(in nodes: [TimelineNode]) -> Int? {
        guard let hoveringId = hoveringNodeId,
              let index = nodes.firstIndex(where: { $0.id == hoveringId }) else { return nil }
        
        switch hoveringPlacement {
        case .before: return index
        case .after: return index + 1
        }
    }
    
    // MARK: - Drag Lifecycle
    
    func startDrag(payload: DragPayload) {
        activePayload = payload
        activeDeckSummary = nil
        hoveringNodeId = nil
        hoveringPlacement = .after
        isDragEnded = false
    }
    
    func startDeckDrag(payload: DragPayload, summary: DeckDragSummary) {
        activePayload = payload
        activeDeckSummary = summary
        hoveringNodeId = nil
        hoveringPlacement = .after
        isDragEnded = false
    }
    
    
    func updatePosition(_ location: CGPoint, nodeFrames: [UUID: CGRect], allowedNodeIds: Set<UUID>) {
        dragLocation = location
        
        // Find the closest node to the drag location
        let candidates = nodeFrames.compactMap { (id, frame) -> (UUID, CGRect, CGFloat)? in
            guard allowedNodeIds.contains(id) else { return nil }
            let distance = abs(frame.midY - location.y)
            return (id, frame, distance)
        }
        
        guard !candidates.isEmpty else {
            hoveringNodeId = nil
            hoveringPlacement = .after
            return
        }
        
        
        // Strategy:
        // 1. Priority: Node frame contains the location.
        // 2. Fallback: Minimum distance to vertical center.
        
        let insideCandidate = candidates.first { (_, frame, _) in
            frame.contains(location)
        }
        
        // If we are strictly inside a node, pick it.
        // Else, pick the closest one by distance.
        let selected: (UUID, CGRect, CGFloat)?
        if let inside = insideCandidate {
            selected = inside
        } else {
            selected = candidates.min { lhs, rhs in
                lhs.2 < rhs.2
            }
        }
        
        guard let finalSelection = selected else {
            hoveringNodeId = nil
            hoveringPlacement = .after
            return
        }
        
        hoveringNodeId = finalSelection.0
        let isAboveCenter = location.y < finalSelection.1.midY
        switch axisDirection {
        case .topToBottom:
            hoveringPlacement = isAboveCenter ? .before : .after
        case .bottomToTop:
            hoveringPlacement = isAboveCenter ? .after : .before
        }
    }
    
    func drop() -> DropAction {
        guard let payload = activePayload, let nodeId = hoveringNodeId else {
            return .cancel
        }
        
        switch payload.type {
        case .cardTemplate(let cardTemplateId):
            return .placeCard(cardTemplateId: cardTemplateId, anchorNodeId: nodeId, placement: hoveringPlacement)
        case .deck(let deckId):
            return .placeDeck(deckId: deckId, anchorNodeId: nodeId, placement: hoveringPlacement)
        case .focusGroup(let memberTemplateIds):
            return .placeFocusGroup(memberTemplateIds: memberTemplateIds, anchorNodeId: nodeId, placement: hoveringPlacement)
        case .node(let draggedNodeId):
            return .moveNode(nodeId: draggedNodeId, anchorNodeId: nodeId, placement: hoveringPlacement)
        }
    }
    
    func cancel() {
        reset()
    }
    
    func reset() {
        activePayload = nil
        activeDeckSummary = nil
        hoveringNodeId = nil
        hoveringPlacement = .after
        // dragLocation = .zero // 坐标系漂移修复 (Solution A): Lock-in final position. Do not reset to zero to prevent "fly to origin" animation artifact.
        dragOffset = .zero
        initialDragLocation = nil
        isDragEnded = false
    }
}
