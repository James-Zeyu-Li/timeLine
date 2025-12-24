import Foundation

enum DragType: Equatable {
    case cardTemplate(UUID)
    case deck(UUID)
}

struct DragPayload: Equatable {
    let type: DragType
    let source: DeckTab
}
