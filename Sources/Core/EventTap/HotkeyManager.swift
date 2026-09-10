import Cocoa

/// Registers a global hotkey (Option + D) using `NSEvent` monitors.
///
/// A **global** monitor fires when the app is *not* frontmost, while
/// a **local** monitor fires when it *is*. Both are needed for
/// consistent behaviour.
final class HotkeyManager {

    // MARK: - Properties

    /// Called on the main thread when the hotkey is pressed.
    var onHotkeyPressed: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// Key code for 'D' on a standard US keyboard.
    private let targetKeyCode: UInt16 = 2

    // MARK: - Public API

    /// Begins listening for the hotkey.
    func start() {
        guard globalMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event   // pass the event through
        }
    }

    /// Stops listening and removes both monitors.
    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    // MARK: - Private

    private func handleKeyEvent(_ event: NSEvent) {
        // Option + D
        guard event.keyCode == targetKeyCode,
              event.modifierFlags.contains(.option) else {
            return
        }

        onHotkeyPressed?()
    }
}
