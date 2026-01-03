import Foundation
import TimeLineCore

@MainActor
final class FocusListStore: ObservableObject {
    @Published private(set) var items: [FocusListItem] = []

    func add(_ item: FocusListItem) {
        items.append(item)
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    func clear() {
        items.removeAll()
    }
}

struct FocusListItem: Identifiable, Equatable {
    enum Source: Equatable {
        case template(UUID)
        case adHoc(CardTemplate)
    }

    let id: UUID
    var source: Source
    var createdAt: Date

    init(id: UUID = UUID(), source: Source, createdAt: Date = Date()) {
        self.id = id
        self.source = source
        self.createdAt = createdAt
    }
}
