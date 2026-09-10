import AppKit
import SwiftUI

// MARK: - DragAllRepresentable

/// An NSViewRepresentable that acts as both:
/// 1. A multi-file dragging source (dragging out drops ALL items together into Finder/other apps)
/// 2. A dragging destination (dropping more files onto an existing shelf adds them)
struct DragAllRepresentable: NSViewRepresentable {
    let items: [StagedItem]
    var onDropFiles: (([URL]) -> Void)?
    var onDragCompleted: (() -> Void)?

    func makeNSView(context: Context) -> DragAllNSView {
        let view = DragAllNSView()
        view.items = items
        view.onDropFiles = onDropFiles
        view.onDragCompleted = onDragCompleted
        return view
    }

    func updateNSView(_ nsView: DragAllNSView, context: Context) {
        nsView.items = items
        nsView.onDropFiles = onDropFiles
        nsView.onDragCompleted = onDragCompleted
    }
}

// MARK: - DragAllNSView

final class DragAllNSView: NSView, NSDraggingSource {

    static var isDraggingOutActive: Bool = false

    var items: [StagedItem] = []
    var onDropFiles: (([URL]) -> Void)?
    var onDragCompleted: (() -> Void)?

    private var dragOrigin: NSPoint = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL, .string, .tiff, .png])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL, .string, .tiff, .png])
    }

    // MARK: - NSDraggingDestination (Accepting drops onto existing items)

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if Self.isDraggingOutActive || (sender.draggingSource as? DragAllNSView != nil) {
            return []
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if Self.isDraggingOutActive || (sender.draggingSource as? DragAllNSView != nil) {
            return []
        }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if Self.isDraggingOutActive || (sender.draggingSource as? DragAllNSView != nil) {
            return false
        }
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            NSLog("[DragAll] 📥 Ingested %d additional file(s) via drop", urls.count)
            DispatchQueue.main.async { [weak self] in
                self?.onDropFiles?(urls)
            }
            return true
        }
        return false
    }

    // MARK: - NSDraggingSource (Dragging all items OUT)

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .withinApplication:
            return [] // NEVER allow dropping back onto our own shelf as a move!
        case .outsideApplication:
            return .every // Finder / Desktop can copy, move, or link!
        @unknown default:
            return .every
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        Self.isDraggingOutActive = false
        NSLog("[DragAll] 🏁 Drag session ended at (%.0f, %.0f) with operation: %@", screenPoint.x, screenPoint.y, String(describing: operation))

        // Check if cursor was released back over our shelf window
        let droppedOnShelf = self.window?.frame.contains(screenPoint) ?? false

        if droppedOnShelf || operation == [] {
            NSLog("[DragAll] ↩️ Dropped back onto shelf zone or cancelled — KEEPING items on shelf!")
            return
        }

        NSLog("[DragAll] ✅ Drag succeeded into external app! Clearing shelf.")
        DispatchQueue.main.async { [weak self] in
            self?.onDragCompleted?()
        }
    }

    // MARK: - Mouse Drag Initiation

    override func mouseDown(with event: NSEvent) {
        dragOrigin = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - dragOrigin.x
        let dy = current.y - dragOrigin.y
        let distance = sqrt(dx * dx + dy * dy)

        // Require a minimum drag movement to initiate
        guard distance > 4, !items.isEmpty else { return }

        Self.isDraggingOutActive = true

        // Build one NSDraggingItem per staged item using standardized NSURL
        var draggingItems: [NSDraggingItem] = []

        for stagedItem in items {
            let url = stagedItem.url.standardizedFileURL
            let draggingItem = NSDraggingItem(pasteboardWriter: url as NSURL)

            let iconSize = NSSize(width: 48, height: 48)
            let icon: NSImage
            if let thumb = stagedItem.thumbnail {
                icon = thumb
            } else {
                icon = NSWorkspace.shared.icon(forFile: url.path)
            }
            icon.size = iconSize

            let frame = NSRect(
                x: current.x - iconSize.width / 2,
                y: current.y - iconSize.height / 2,
                width: iconSize.width,
                height: iconSize.height
            )

            draggingItem.setDraggingFrame(frame, contents: icon)
            draggingItems.append(draggingItem)
        }

        guard !draggingItems.isEmpty else {
            Self.isDraggingOutActive = false
            return
        }

        NSLog("[DragAll] 🚀 Initiating multi-item drag with %d items.", draggingItems.count)
        beginDraggingSession(with: draggingItems, event: event, source: self)
    }
}
