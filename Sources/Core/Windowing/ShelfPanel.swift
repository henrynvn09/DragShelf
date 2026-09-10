import AppKit

// MARK: - ShelfPanel

final class ShelfPanel: NSPanel {

    // MARK: Properties

    private var isDragSessionActive: Bool = false

    // MARK: Initialization

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isMovableByWindowBackground = false
        isMovable = true
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false

        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
    }

    // MARK: Key / Main Behavior

    override var canBecomeKey: Bool {
        !isDragSessionActive
    }

    override var canBecomeMain: Bool {
        false
    }

    // MARK: Drag Session

    func setDragSessionActive(_ active: Bool) {
        isDragSessionActive = active
    }
}
