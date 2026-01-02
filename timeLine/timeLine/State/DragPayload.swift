import Foundation

enum DragType: Equatable {
    case cardTemplate(UUID)
    case deck(UUID)
    case focusGroup([UUID])
}

struct DragPayload: Equatable {
    let type: DragType
    let source: DeckTab
}
