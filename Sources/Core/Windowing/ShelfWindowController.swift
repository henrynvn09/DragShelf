import AppKit
import SwiftUI
import Combine

// MARK: - ShelfWindowController

final class ShelfWindowController: NSWindowController {

    // MARK: Properties

    let id: UUID = UUID()
    let shelfStore: ShelfStore
    weak var coordinator: ShelfCoordinator?

    private var cancellables = Set<AnyCancellable>()

    // MARK: Initialization

    init(store: ShelfStore = ShelfStore()) {
        let contentRect = NSRect(x: 0, y: 0, width: 175, height: 185)
        let panel = ShelfPanel(contentRect: contentRect)
        self.shelfStore = store
        super.init(window: panel)

        let containerView = ShelfContainerView(store: store, onClose: { [weak self] in
            guard let self else { return }
            self.coordinator?.dismissShelf(self)
        })
        let hostingView = NSHostingView(rootView: containerView)
        hostingView.frame = contentRect
        panel.contentView = hostingView

        observeStoreChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var hasHadItems: Bool = false

    // MARK: Observation

    private func observeStoreChanges() {
        shelfStore.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                guard let self else { return }
                if !items.isEmpty {
                    self.hasHadItems = true
                } else if self.hasHadItems && !self.shelfStore.isPinned {
                    NSLog("[ShelfWindowController] 🧹 Shelf had items and was emptied — auto-dismissing.")
                    self.coordinator?.controllerDidBecomeEmpty(self)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Positioning

    func positionAtCursor() {
        guard let panel = window else { return }
        let mouseLocation = NSEvent.mouseLocation
        let windowSize = panel.frame.size

        var origin = NSPoint(
            x: mouseLocation.x - windowSize.width / 2,
            y: mouseLocation.y - windowSize.height / 2
        )

        // Clamp to visible screen bounds
        if let screenFrame = NSScreen.main?.visibleFrame {
            origin.x = max(screenFrame.minX, min(origin.x, screenFrame.maxX - windowSize.width))
            origin.y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - windowSize.height))
        }

        panel.setFrameOrigin(origin)
    }

    // MARK: Animations

    func animateIn() {
        guard let panel = window else { return }

        NSLog("[ShelfWindowController] 🪟 Showing shelf panel at (%.0f, %.0f)", panel.frame.origin.x, panel.frame.origin.y)
        panel.alphaValue = 1.0
        panel.orderFrontRegardless()

        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.95, y: 0.95))
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                contentView.layer?.setAffineTransform(.identity)
            }
        }
    }

    func animateOut(completion: (() -> Void)? = nil) {
        guard let panel = window else {
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.close()
            completion?()
        })
    }
}
