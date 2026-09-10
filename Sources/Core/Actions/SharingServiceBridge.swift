import AppKit

/// Bridges StagedItems to the macOS NSSharingServicePicker.
final class SharingServiceBridge {

    // MARK: - Share

    /// Presents the macOS sharing picker for the given staged items,
    /// anchored to the specified view.
    static func share(
        items: [StagedItem],
        relativeTo view: NSView,
        preferredEdge: NSRectEdge = .minY
    ) {
        let shareables = shareableItems(from: items)
        guard !shareables.isEmpty else { return }

        let picker = NSSharingServicePicker(items: shareables)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: preferredEdge)
    }

    // MARK: - Conversion

    /// Converts an array of StagedItems into shareable objects.
    ///
    /// - Files and web images → URL
    /// - Text clippings → String (the content at the URL, or the URL as a string)
    /// - URLs → URL
    static func shareableItems(from stagedItems: [StagedItem]) -> [Any] {
        stagedItems.compactMap { item in
            switch item.kind {
            case .textClipping:
                // Try to read the text content; fall back to the URL string
                if let text = try? String(contentsOf: item.url, encoding: .utf8) {
                    return text as Any
                }
                return item.url.absoluteString as Any

            case .file, .webImage, .url:
                return item.url as Any
            }
        }
    }
}
