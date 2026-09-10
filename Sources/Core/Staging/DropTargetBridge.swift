import Cocoa
import UniformTypeIdentifiers

/// An `NSView` subclass that acts as a drop target, accepting files,
/// URLs, images, and text from drag-and-drop operations and ingesting
/// them into a `ShelfStore`.
final class DropTargetBridge: NSView {

    // MARK: - Properties

    /// The shelf store to add dropped items to.
    var shelfStore: ShelfStore?

    /// Thumbnail generator used to produce previews after ingestion.
    var thumbnailManager: ThumbnailManager?

    // MARK: - Initialisation

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerDragTypes()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerDragTypes()
    }

    private func registerDragTypes() {
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            .tiff,
            .png,
        ])
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        setHighlight(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setHighlight(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        setHighlight(false)

        let pasteboard = sender.draggingPasteboard

        var stagedItems: [StagedItem] = []

        // 1. File URLs
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !fileURLs.isEmpty {
            for url in fileURLs {
                let title = url.lastPathComponent
                let size = fileSizeForURL(url)
                let item = StagedItem(
                    url: url,
                    kind: .file,
                    title: title,
                    fileSize: size
                )
                stagedItems.append(item)
            }
        }

        // 2. Non-file URLs (web links)
        if stagedItems.isEmpty,
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
               .urlReadingFileURLsOnly: false
           ]) as? [URL] {
            let webURLs = urls.filter { !$0.isFileURL }
            for url in webURLs {
                if let cached = TempCacheManager.shared.cacheURL(url) {
                    let item = StagedItem(
                        url: cached,
                        kind: .url,
                        title: url.absoluteString,
                        fileSize: nil
                    )
                    stagedItems.append(item)
                }
            }
        }

        // 3. Image data (TIFF / PNG)
        if stagedItems.isEmpty {
            if let tiffData = pasteboard.data(forType: .tiff),
               let cached = TempCacheManager.shared.cacheImageData(tiffData, suggestedName: nil) {
                let item = StagedItem(
                    url: cached,
                    kind: .webImage,
                    title: cached.lastPathComponent,
                    fileSize: Int64(tiffData.count)
                )
                stagedItems.append(item)
            } else if let pngData = pasteboard.data(forType: .png),
                      let cached = TempCacheManager.shared.cacheImageData(pngData, suggestedName: "image.png") {
                let item = StagedItem(
                    url: cached,
                    kind: .webImage,
                    title: cached.lastPathComponent,
                    fileSize: Int64(pngData.count)
                )
                stagedItems.append(item)
            }
        }

        // 4. Plain text
        if stagedItems.isEmpty,
           let text = pasteboard.string(forType: .string), !text.isEmpty {
            if let cached = TempCacheManager.shared.cacheText(text) {
                let title = String(text.prefix(60))
                let item = StagedItem(
                    url: cached,
                    kind: .textClipping,
                    title: title,
                    fileSize: Int64(text.utf8.count)
                )
                stagedItems.append(item)
            }
        }

        guard !stagedItems.isEmpty else { return false }

        // 5. Ingest into the shelf store.
        shelfStore?.addItems(stagedItems)

        // 6. Request thumbnails.
        if let thumbnailManager = thumbnailManager {
            for item in stagedItems {
                Task {
                    await thumbnailManager.generateThumbnail(for: item)
                }
            }
        }

        return true
    }

    // MARK: - Helpers

    private func setHighlight(_ highlighted: Bool) {
        layer?.borderWidth = highlighted ? 2.0 : 0.0
        layer?.borderColor = highlighted ? NSColor.controlAccentColor.cgColor : nil
    }

    private func fileSizeForURL(_ url: URL) -> Int64? {
        guard url.isFileURL else { return nil }
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            return attrs[.size] as? Int64
        } catch {
            return nil
        }
    }
}
