import AppKit

// MARK: - MenuBarController

final class MenuBarController {

    // MARK: Properties

    private var statusItem: NSStatusItem

    // MARK: Initialization

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "tray.and.arrow.down",
                accessibilityDescription: "Dropover Clone"
            )
        }

        statusItem.menu = buildMenu()
    }

    // MARK: Menu Construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let newShelfItem = NSMenuItem(
            title: "New Shelf",
            action: #selector(newShelfAction(_:)),
            keyEquivalent: "n"
        )
        newShelfItem.target = self
        menu.addItem(newShelfItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitAction(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: Actions

    @objc private func newShelfAction(_ sender: NSMenuItem) {
        ShelfCoordinator.shared.spawnShelfAtCursor()
    }

    @objc private func quitAction(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}
