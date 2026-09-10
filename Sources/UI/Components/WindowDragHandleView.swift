import AppKit
import SwiftUI

/// An NSViewRepresentable that allows dragging the parent NSWindow
/// when clicking and dragging on it, using the native `window?.performDrag(with:)`.
struct WindowDragHandleView: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragNSView {
        WindowDragNSView()
    }

    func updateNSView(_ nsView: WindowDragNSView, context: Context) {}
}

final class WindowDragNSView: NSView {
    private var initialMouseScreen: NSPoint = .zero
    private var initialWindowOrigin: NSPoint = .zero
    private var isDragging: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        initialMouseScreen = NSEvent.mouseLocation
        initialWindowOrigin = window.frame.origin
        isDragging = true
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window, isDragging else { return }
        if (NSEvent.pressedMouseButtons & 1) == 0 {
            isDragging = false
            NSCursor.pop()
            return
        }
        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - initialMouseScreen.x
        let dy = currentMouse.y - initialMouseScreen.y
        window.setFrameOrigin(NSPoint(x: initialWindowOrigin.x + dx, y: initialWindowOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            NSCursor.pop()
        }
    }
}
