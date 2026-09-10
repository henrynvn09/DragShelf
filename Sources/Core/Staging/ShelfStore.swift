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

    // MARK: Uniqueness Checks

    func containsURL(_ url: URL) -> Bool {
        if url.isFileURL {
            let targetPath = url.standardizedFileURL.path
            return items.contains { $0.url.isFileURL && $0.url.standardizedFileURL.path == targetPath }
        } else {
            let targetString = url.absoluteString
            return items.contains { $0.url.absoluteString == targetString }
        }
    }

    func containsItem(_ item: StagedItem) -> Bool {
        containsURL(item.url)
    }

    // MARK: Mutation Methods

    func addItem(_ item: StagedItem) {
        guard !containsItem(item) else {
            NSLog("[ShelfStore] ⚠️ Item already staged (duplicate ignored): %@", item.url.lastPathComponent)
            return
        }
        items.append(item)
    }

    func addItems(_ newItems: [StagedItem]) {
        for item in newItems {
            addItem(item)
        }
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func removeAll() {
        items.removeAll()
    }
}
