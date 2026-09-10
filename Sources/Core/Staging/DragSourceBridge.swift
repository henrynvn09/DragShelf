import Cocoa
import UniformTypeIdentifiers

/// An `NSView` subclass that acts as a drag **source**, allowing the
/// user to drag staged items out of the shelf window into other apps.
final class DragSourceBridge: NSView, NSDraggingSource {

    // MARK: - Properties

    /// The items currently eligible for dragging.
    var items: [StagedItem] = []

    /// Called after a successful drag operation with the items that were dragged.
    var onDragCompleted: (([StagedItem]) -> Void)?

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            return .copy
        case .withinApplication:
            return .move
        @unknown default:
            return .copy
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        if operation != [] {
            onDragCompleted?(items)
        }
    }

    // MARK: - Initiating a drag

    /// Begins a drag session with the given staged items.
    ///
    /// - Parameters:
    ///   - items: The `StagedItem`s to drag.
    ///   - event: The mouse-down event that initiated the drag.
    func beginDragging(with items: [StagedItem], event: NSEvent) {
        self.items = items

        var draggingItems: [NSDraggingItem] = []

        for (index, staged) in items.enumerated() {
            let pasteboardItem = NSPasteboardItem()

            // Write the URL as a file URL string.
            if staged.url.isFileURL {
                pasteboardItem.setString(staged.url.absoluteString, forType: .fileURL)
            } else {
                pasteboardItem.setString(staged.url.absoluteString, forType: .URL)
            }

            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)

            // Use the item's thumbnail or a generic icon as the drag image.
            let image = staged.thumbnail
                ?? NSWorkspace.shared.icon(forFile: staged.url.path)
            let size = NSSize(width: 64, height: 64)
            let origin = NSPoint(x: CGFloat(index) * 10, y: 0)
            draggingItem.setDraggingFrame(NSRect(origin: origin, size: size), contents: image)

            draggingItems.append(draggingItem)
        }

        guard !draggingItems.isEmpty else { return }

        beginDraggingSession(with: draggingItems, event: event, source: self)
    }
}
