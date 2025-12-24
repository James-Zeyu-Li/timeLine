import SwiftUI
import Combine
import TimeLineCore

// MARK: - Drop Action

enum DropAction: Equatable {
    case placeCard(cardTemplateId: UUID, anchorNodeId: UUID)
    case placeDeck(deckId: UUID, anchorNodeId: UUID)
    case cancel
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
    
    // MARK: - Internal State
    
    private(set) var activePayload: DragPayload?
    
    // MARK: - Drag Lifecycle
    
    // MARK: - Drag Lifecycle
    
    func startDrag(payload: DragPayload) {
        activePayload = payload
        activeDeckSummary = nil
        hoveringNodeId = nil
    }
    
    func startDeckDrag(payload: DragPayload, summary: DeckDragSummary) {
        activePayload = payload
        activeDeckSummary = summary
        hoveringNodeId = nil
    }
    
    func updatePosition(_ location: CGPoint, nodeFrames: [UUID: CGRect]) {
        dragLocation = location
        
        // Find the nearest node center among frames that contain the drag location.
        let candidates = nodeFrames.compactMap { (id, frame) -> (UUID, CGPoint)? in
            guard frame.contains(location) else { return nil }
            let center = CGPoint(x: frame.midX, y: frame.midY)
            return (id, center)
        }
        guard !candidates.isEmpty else {
            hoveringNodeId = nil
            return
        }
        hoveringNodeId = candidates.min { lhs, rhs in
            let left = (lhs.1.x - location.x) * (lhs.1.x - location.x)
                + (lhs.1.y - location.y) * (lhs.1.y - location.y)
            let right = (rhs.1.x - location.x) * (rhs.1.x - location.x)
                + (rhs.1.y - location.y) * (rhs.1.y - location.y)
            return left < right
        }?.0
    }
    
    func drop() -> DropAction {
        guard let payload = activePayload, let nodeId = hoveringNodeId else {
            return .cancel
        }
        
        switch payload.type {
        case .cardTemplate(let cardTemplateId):
            return .placeCard(cardTemplateId: cardTemplateId, anchorNodeId: nodeId)
        case .deck(let deckId):
            return .placeDeck(deckId: deckId, anchorNodeId: nodeId)
        }
    }
    
    func cancel() {
        reset()
    }
    
    func reset() {
        activePayload = nil
        activeDeckSummary = nil
        hoveringNodeId = nil
        dragLocation = .zero
    }
}
