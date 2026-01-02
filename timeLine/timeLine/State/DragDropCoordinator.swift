import SwiftUI
import Combine
import TimeLineCore

// MARK: - Drop Action

enum DropAction: Equatable {
    case placeCard(cardTemplateId: UUID, anchorNodeId: UUID, placement: DropPlacement)
    case placeDeck(deckId: UUID, anchorNodeId: UUID, placement: DropPlacement)
    case placeFocusGroup(memberTemplateIds: [UUID], anchorNodeId: UUID, placement: DropPlacement)
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
    @Published var hoveringNodeId: UUID?
    @Published var activeDeckSummary: DeckDragSummary?
    @Published var hoveringPlacement: DropPlacement = .after
    
    // MARK: - Internal State
    
    private(set) var activePayload: DragPayload?
    private var axisDirection: DropAxisDirection = .bottomToTop
    
    // MARK: - Drag Lifecycle
    
    func startDrag(payload: DragPayload) {
        activePayload = payload
        activeDeckSummary = nil
        hoveringNodeId = nil
        hoveringPlacement = .after
    }
    
    func startDeckDrag(payload: DragPayload, summary: DeckDragSummary) {
        activePayload = payload
        activeDeckSummary = summary
        hoveringNodeId = nil
        hoveringPlacement = .after
    }
    
    
    func updatePosition(_ location: CGPoint, nodeFrames: [UUID: CGRect], allowedNodeIds: Set<UUID>) {
        dragLocation = location
        
        // Find the nearest node center among frames that contain the drag location.
        let candidates = nodeFrames.compactMap { (id, frame) -> (UUID, CGRect, CGPoint)? in
            guard allowedNodeIds.contains(id) else { return nil }
            guard frame.contains(location) else { return nil }
            let center = CGPoint(x: frame.midX, y: frame.midY)
            return (id, frame, center)
        }
        guard !candidates.isEmpty else {
            hoveringNodeId = nil
            hoveringPlacement = .after
            return
        }
        let bestCandidate = candidates.min { lhs, rhs in
            let left = (lhs.2.x - location.x) * (lhs.2.x - location.x)
                + (lhs.2.y - location.y) * (lhs.2.y - location.y)
            let right = (rhs.2.x - location.x) * (rhs.2.x - location.x)
                + (rhs.2.y - location.y) * (rhs.2.y - location.y)
            return left < right
        }
        guard let selected = bestCandidate else {
            hoveringNodeId = nil
            hoveringPlacement = .after
            return
        }
        hoveringNodeId = selected.0
        let isAboveCenter = location.y < selected.1.midY
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
        dragLocation = .zero
    }
}
