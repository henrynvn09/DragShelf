import AppKit

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: Properties

    private var menuBarController: MenuBarController?
    private var eventTapManager: EventTapManager?
    private var hotkeyManager: HotkeyManager?

    // MARK: NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSLog("[AppDelegate] ✅ App launched as accessory (menu bar only).")

        // Initialize menu bar
        menuBarController = MenuBarController()
        NSLog("[AppDelegate] ✅ Menu bar controller initialized.")

        // Check and request accessibility permissions for shake detection
        let trusted = checkAccessibilityPermissions()
        NSLog("[AppDelegate] Accessibility trusted: %@", trusted ? "YES" : "NO")

        // Initialize input subsystems
        setupEventTap(trusted: trusted)
        setupHotkey()
    }

    // MARK: Input Subsystem Wiring

    private func setupEventTap(trusted: Bool) {
        guard trusted else { return }
        let manager = EventTapManager()
        manager.onShakeDetected = {
            DispatchQueue.main.async {
                ShelfCoordinator.shared.spawnShelfAtCursor()
            }
        }
        manager.onDragSessionEnded = {
            ShelfCoordinator.shared.dragSessionDidEnd()
        }
        manager.start()
        eventTapManager = manager
    }

    private func setupHotkey() {
        let manager = HotkeyManager()
        manager.onHotkeyPressed = {
            ShelfCoordinator.shared.spawnShelfAtCursor()
        }
        manager.start()
        hotkeyManager = manager
    }

    // MARK: Accessibility Permissions

    @discardableResult
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
