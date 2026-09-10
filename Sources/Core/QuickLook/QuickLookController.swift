import Quartz
import AppKit

/// Coordinates QLPreviewPanel for previewing staged items.
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    // MARK: - Singleton

    static let shared = QuickLookController()

    // MARK: - Properties

    var items: [StagedItem] = []
    var selectedIndex: Int = 0

    // MARK: - Preview Toggle

    /// Toggles the Quick Look preview panel for the given items.
    ///
    /// If the panel is already visible showing the same items, it will be closed.
    /// Otherwise, it opens with the provided items starting at `selectedIndex`.
    func togglePreview(for items: [StagedItem], selectedIndex: Int = 0) {
        let panel = QLPreviewPanel.shared()!

        // If the panel is visible and showing the same set of items, close it.
        if panel.isVisible,
           self.items.map(\.id) == items.map(\.id) {
            panel.orderOut(nil)
            return
        }

        self.items = items
        self.selectedIndex = min(selectedIndex, max(items.count - 1, 0))

        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = self.selectedIndex
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        items.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard index >= 0, index < items.count else { return nil }
        return items[index].url as QLPreviewItem
    }

    // MARK: - QLPreviewPanelDelegate

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Let the panel handle keyboard navigation
        return false
    }
}
