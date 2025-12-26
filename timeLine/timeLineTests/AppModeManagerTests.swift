import XCTest
@testable import timeLine

@MainActor
final class AppModeManagerTests: XCTestCase {
    
    func testDraggingOnlyFromDeckOverlay() async {
        let manager = AppModeManager()
        let cardId = UUID()
        let payload = DragPayload(type: .cardTemplate(cardId), source: .cards)
        
        manager.enter(.dragging(payload))
        XCTAssertEqual(manager.mode, .homeCollapsed)
        
        manager.enter(.deckOverlay(.cards))
        manager.enter(.dragging(payload))
        
        XCTAssertEqual(manager.mode, .dragging(payload))
    }
    
    func testCardDetailEditAllowedFromDeckOrHomeCollapsed() async {
        let manager = AppModeManager()
        let cardId = UUID()
        
        manager.enter(.cardEdit(cardTemplateId: cardId, returnMode: .homeCollapsed))
        if case .cardEdit(_, let returnMode) = manager.mode {
            XCTAssertEqual(returnMode, .homeCollapsed)
        } else {
            XCTFail("Expected cardEdit from homeCollapsed")
        }
        
        manager.exitCardEdit()
        manager.enter(.deckOverlay(.decks))
        manager.enter(.cardEdit(cardTemplateId: cardId, returnMode: .homeCollapsed))
        
        if case .cardEdit(_, let returnMode) = manager.mode {
            XCTAssertEqual(returnMode, .deckOverlay(.decks))
        } else {
            XCTFail("Expected cardEdit from deckOverlay")
        }
    }
    
    func testCardDetailEditForbiddenFromHomeExpandedAndDragging() async {
        let manager = AppModeManager()
        let cardId = UUID()
        let payload = DragPayload(type: .cardTemplate(cardId), source: .cards)
        
        manager.enter(.homeExpanded)
        manager.enter(.cardEdit(cardTemplateId: cardId, returnMode: .homeCollapsed))
        XCTAssertEqual(manager.mode, .homeExpanded)
        
        manager.enter(.homeCollapsed)
        manager.enter(.deckOverlay(.cards))
        manager.enter(.dragging(payload))
        manager.enter(.cardEdit(cardTemplateId: cardId, returnMode: .homeCollapsed))
        XCTAssertEqual(manager.mode, .dragging(payload))
    }
    
    func testHomeExpandedOnlyFromHomeCollapsed() async {
        let manager = AppModeManager()
        
        manager.enter(.deckOverlay(.cards))
        manager.enter(.homeExpanded)
        XCTAssertEqual(manager.mode, .deckOverlay(.cards))
        
        manager.exitToHome()
        manager.enter(.homeExpanded)
        XCTAssertEqual(manager.mode, .homeExpanded)
    }
    
    func testExitDragReturnsToDeckOverlay() async {
        let manager = AppModeManager()
        let cardId = UUID()
        let payload = DragPayload(type: .cardTemplate(cardId), source: .cards)
        
        manager.enter(.deckOverlay(.cards))
        manager.enter(.dragging(payload))
        manager.exitDrag(success: true)
        
        XCTAssertEqual(manager.mode, .deckOverlay(.cards))
    }
    
    func testExitCardEditReturnsToCapturedMode() async {
        let manager = AppModeManager()
        let cardId = UUID()
        
        manager.enter(.deckOverlay(.decks))
        manager.enter(.cardEdit(cardTemplateId: cardId, returnMode: .homeCollapsed))
        manager.exitCardEdit()
        
        XCTAssertEqual(manager.mode, .deckOverlay(.decks))
    }
    
    func testDeckEditAllowedFromDeckOverlayAndHomeCollapsed() async {
        let manager = AppModeManager()
        let deckId = UUID()
        
        manager.enter(.deckEdit(deckId: deckId, returnMode: .homeCollapsed))
        if case .deckEdit(_, let returnMode) = manager.mode {
            XCTAssertEqual(returnMode, .homeCollapsed)
        } else {
            XCTFail("Expected deckEdit from homeCollapsed")
        }
        
        manager.exitDeckEdit()
        manager.enter(.deckOverlay(.decks))
        manager.enter(.deckEdit(deckId: deckId, returnMode: .homeCollapsed))
        
        if case .deckEdit(_, let returnMode) = manager.mode {
            XCTAssertEqual(returnMode, .deckOverlay(.decks))
        } else {
            XCTFail("Expected deckEdit from deckOverlay")
        }
    }
}
