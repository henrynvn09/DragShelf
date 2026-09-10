import AppKit
import Combine

// MARK: - ShelfStore

final class ShelfStore: ObservableObject {

    // MARK: Published Properties

    @Published var items: [StagedItem] = []
    @Published var isPinned: Bool = false

    // MARK: Computed Properties

    var isEmpty: Bool {
        items.isEmpty
    }

    // MARK: Mutation Methods

    func addItem(_ item: StagedItem) {
        items.append(item)
    }

    func addItems(_ newItems: [StagedItem]) {
        items.append(contentsOf: newItems)
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func removeAll() {
        items.removeAll()
    }
}
