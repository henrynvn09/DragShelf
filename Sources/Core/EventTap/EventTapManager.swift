import Cocoa
import CoreGraphics

/// Installs drag monitoring and shake detection using a clean, unified
/// hardware polling engine at 50Hz.
///
/// Ensures a single consistent coordinate space (NSEvent.mouseLocation)
/// to eliminate coordinate jumping and false reversals.
/// Strictly gates on NSPasteboard.Name.drag changeCount so non-drag
/// movements and empty-space selections are 100% ignored.
final class EventTapManager {

    // MARK: - Properties

    private var pollTimer: Timer?
    private var shakeDetector = ShakeDetector()

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var pasteboardCountAtMouseDown: Int = -1
    private var isFileDragActive: Bool = false
    private var isMouseDown: Bool = false

    private var isDragging: Bool = false
    private var dragEventCount: Int = 0

    /// Called on the **main queue** when a shake gesture is recognised.
    var onShakeDetected: (() -> Void)?

    /// Called on the **main queue** when a drag session concludes (mouse button released).
    var onDragSessionEnded: (() -> Void)?

    // MARK: - Lifecycle

    deinit {
        stop()
    }

    // MARK: - Public API

    /// Starts the 50Hz unified hardware polling engine.
    func start() {
        startHardwarePolling()
        NSLog("[EventTapManager] 🚀 Unified 50Hz drag monitor active.")
    }

    // MARK: - Drag State Verification

    /// Checks if a genuine drag session has been initiated by an application
    /// (e.g. Finder, Safari, Chrome) writing items onto the system drag pasteboard.
    private func checkIsFileDragActive() -> Bool {
        if isFileDragActive { return true }
        let currentCount = dragPasteboard.changeCount
        if pasteboardCountAtMouseDown != -1 && currentCount != pasteboardCountAtMouseDown {
            isFileDragActive = true
            NSLog("[EventTapManager] 📂 Genuine drag session verified! (changeCount: %d -> %d)", pasteboardCountAtMouseDown, currentCount)
            return true
        }
        return false
    }

    private func handleMouseDown() {
        isMouseDown = true
        pasteboardCountAtMouseDown = dragPasteboard.changeCount
        isFileDragActive = false
        dragEventCount = 0
        shakeDetector.reset()
    }

    private func handleMouseUp() {
        let wasDragging = isFileDragActive || isDragging
        isMouseDown = false
        pasteboardCountAtMouseDown = -1
        isFileDragActive = false
        isDragging = false
        dragEventCount = 0
        shakeDetector.reset()

        if wasDragging {
            DispatchQueue.main.async { [weak self] in
                self?.onDragSessionEnded?()
            }
        }
    }

    // MARK: - Unified Hardware State Poller (50Hz)

    private func startHardwarePolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let isLeftDown = (NSEvent.pressedMouseButtons & 1) != 0 ||
                             CGEventSource.buttonState(.hidSystemState, button: .left)

            if isLeftDown {
                if !self.isMouseDown {
                    self.handleMouseDown()
                }

                // STRICT CHECK: Only process motion if a genuine file drag session has begun
                if self.checkIsFileDragActive() {
                    let location = NSEvent.mouseLocation
                    self.processDrag(at: location)
                }
            } else if self.isMouseDown {
                self.handleMouseUp()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    // MARK: - Teardown

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil

        shakeDetector.reset()
        isDragging = false
        isMouseDown = false
        isFileDragActive = false
    }

    // MARK: - Drag Processing & Shake Detection

    private func processDrag(at point: CGPoint) {
        isDragging = true
        dragEventCount += 1

        if dragEventCount % 25 == 1 {
            NSLog("[Drag] 📍 Drag #%d at (%.0f, %.0f)", dragEventCount, point.x, point.y)
        }

        if shakeDetector.processDragEvent(point: point) {
            NSLog("[Drag] 🎉 DELIBERATE SHAKE DETECTED! Spawning shelf.")
            DispatchQueue.main.async { [weak self] in
                self?.onShakeDetected?()
            }
        }
    }
}
