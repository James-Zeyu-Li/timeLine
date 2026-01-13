import Foundation
import Combine

// MARK: - Deck Tab

enum DeckTab: String, CaseIterable {
    case cards
    case library
    case decks
}

// MARK: - App Mode

indirect enum AppMode: Equatable {
    case homeCollapsed
    case homeExpanded
    case deckOverlay(DeckTab)
    case dragging(DragPayload)
    case cardEdit(cardTemplateId: UUID, returnMode: AppMode)
    case deckEdit(deckId: UUID, returnMode: AppMode)
}

// MARK: - App Mode Manager

@MainActor
final class AppModeManager: ObservableObject {
    
    @Published private(set) var mode: AppMode = .homeCollapsed
    
    // MARK: - Transition Rules
    
    func enter(_ newMode: AppMode) {
        switch newMode {
        case .deckOverlay:
            // Allowed only from home modes
            switch mode {
            case .homeCollapsed, .homeExpanded, .deckOverlay:
                mode = newMode
            default:
                return
            }
            
        case .dragging(let payload):
            // Allow dragging from deckOverlay (card/deck drags) or home modes (node reordering)
            switch mode {
            case .deckOverlay, .homeCollapsed, .homeExpanded:
                mode = .dragging(payload)
            default:
                return
            }
            
        case .cardEdit(let id, _):
            // Allowed from deckOverlay or home (timeline card action)
            switch mode {
            case .deckOverlay(let tab):
                mode = .cardEdit(cardTemplateId: id, returnMode: .deckOverlay(tab))
            case .homeCollapsed:
                mode = .cardEdit(cardTemplateId: id, returnMode: .homeCollapsed)
            case .homeExpanded, .dragging, .cardEdit, .deckEdit:
                return
            }
            
        case .deckEdit(let id, _):
            // Allowed from deckOverlay or home (timeline card action)
            switch mode {
            case .deckOverlay(let tab):
                mode = .deckEdit(deckId: id, returnMode: .deckOverlay(tab))
            case .homeCollapsed:
                mode = .deckEdit(deckId: id, returnMode: .homeCollapsed)
            case .homeExpanded, .dragging, .cardEdit, .deckEdit:
                return
            }
            
        case .homeExpanded:
            // Only allowed from homeCollapsed
            guard case .homeCollapsed = mode else { return }
            mode = newMode
            
        case .homeCollapsed:
            mode = newMode
        }
    }

    func enterCardEdit(cardTemplateId: UUID) {
        enter(.cardEdit(cardTemplateId: cardTemplateId, returnMode: .homeCollapsed))
    }
    
    func enterDeckEdit(deckId: UUID) {
        enter(.deckEdit(deckId: deckId, returnMode: .homeCollapsed))
    }
    
    // MARK: - Exit Helpers
    
    func exitToHome() {
        mode = .homeCollapsed
    }
    
    func exitDrag(success: Bool) {
        switch mode {
        case .dragging(let payload):
            // Node drags return to home, deck/card drags return to deck overlay
            if case .node = payload.type {
                mode = .homeCollapsed
            } else {
                mode = .deckOverlay(payload.source)  // return to deck for chain-add
            }
        default:
            return
        }
    }
    
    func exitCardEdit() {
        guard case .cardEdit(_, let returnMode) = mode else { return }
        mode = returnMode
    }
    
    func exitDeckEdit() {
        guard case .deckEdit(_, let returnMode) = mode else { return }
        mode = returnMode
    }
    
    func closeDeck() {
        guard case .deckOverlay = mode else { return }
        exitToHome()
    }
    
    // MARK: - Computed Helpers
    
    var isOverlayActive: Bool {
        switch mode {
        case .deckOverlay, .dragging, .cardEdit, .deckEdit:
            return true
        default:
            return false
        }
    }
    
    var currentDeckTab: DeckTab? {
        switch mode {
        case .deckOverlay(let tab):
            return tab
        case .dragging(let payload):
            return payload.source
        default:
            return nil
        }
    }
    
    var isDragging: Bool {
        switch mode {
        case .dragging:
            return true
        default:
            return false
        }
    }
    
    var draggingDeckId: UUID? {
        if case .dragging(let payload) = mode,
           case .deck(let id) = payload.type {
            return id
        }
        return nil
    }
    
    var draggingCardId: UUID? {
        if case .dragging(let payload) = mode,
           case .cardTemplate(let id) = payload.type {
            return id
        }
        return nil
    }
}
