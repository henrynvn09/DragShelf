import AppKit

// MARK: - ShelfCoordinator

/// Singleton coordinator ensuring only ONE active shelf exists at any time.
final class ShelfCoordinator {

    // MARK: Singleton

    static let shared = ShelfCoordinator()

    // MARK: Properties

    /// The single active shelf controller.
    private(set) var activeController: ShelfWindowController?

    var isShelfVisible: Bool {
        activeController != nil
    }

    // MARK: Initialization

    private init() {}

    // MARK: Shelf Lifecycle

    func spawnShelfAtCursor() {
        // If a shelf is already visible on screen, keep it firmly locked in place.
        // It should NEVER move along with the cursor during a drag.
        if activeController != nil {
            NSLog("[ShelfCoordinator] 📦 Shelf is already visible — staying locked in place.")
            return
        }

        NSLog("[ShelfCoordinator] 📦 Spawning single shelf at cursor...")
        let controller = ShelfWindowController()
        controller.coordinator = self
        controller.positionAtCursor()
        controller.animateIn()
        activeController = controller
    }

    func dismissShelf(_ controller: ShelfWindowController) {
        controller.animateOut { [weak self] in
            if self?.activeController?.id == controller.id {
                self?.activeController = nil
                NSLog("[ShelfCoordinator] 🧹 Single shelf dismissed.")
            }
        }
    }

    func dismissAllShelves() {
        if let controller = activeController {
            dismissShelf(controller)
        }
    }

    // MARK: Empty Shelf Handling

    func controllerDidBecomeEmpty(_ controller: ShelfWindowController) {
        dismissShelf(controller)
    }

    // MARK: Drag Session Ended Handling

    /// Called when the user releases the mouse button. If the shelf was summoned
    /// but remains empty (the user dropped the file elsewhere or cancelled),
    /// auto-dismiss the empty shelf immediately.
    func dragSessionDidEnd() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self, let existing = self.activeController else { return }
            if existing.shelfStore.isEmpty && !existing.shelfStore.isPinned {
                NSLog("[ShelfCoordinator] 🧹 Mouse released and shelf is empty (dropped elsewhere) — killing shelf.")
                self.dismissShelf(existing)
            }
        }
    }
}
