import Cocoa
import QuickLookThumbnailing

/// Generates and caches thumbnails for staged items using the
/// system's QuickLook thumbnail generator.
final class ThumbnailManager {

    // MARK: - Singleton

    static let shared = ThumbnailManager()

    // MARK: - Cache

    private let cache: NSCache<NSURL, NSImage> = {
        let c = NSCache<NSURL, NSImage>()
        c.countLimit = 200
        return c
    }()

    // MARK: - Public API

    /// Generates a thumbnail for the given `StagedItem`.
    ///
    /// The result is cached and also assigned to `item.thumbnail`
    /// on the main thread.
    ///
    /// - Parameters:
    ///   - item: The staged item to generate a thumbnail for.
    ///   - size: The desired thumbnail dimensions (points).
    func generateThumbnail(
        for item: StagedItem,
        size: CGSize = CGSize(width: 80, height: 80)
    ) async {
        let key = item.url as NSURL

        // 1. Return cached thumbnail immediately.
        if let cached = cache.object(forKey: key) {
            await MainActor.run { item.thumbnail = cached }
            return
        }

        // 2. Request from QuickLook.
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: size,
            scale: 2.0,
            representationTypes: .all
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let image = representation.nsImage
            cache.setObject(image, forKey: key)
            await MainActor.run { item.thumbnail = image }
        } catch {
            // 3. Fallback: workspace icon resized to target size.
            let icon = NSWorkspace.shared.icon(forFile: item.url.path)
            let resized = resizeImage(icon, to: size)
            cache.setObject(resized, forKey: key)
            await MainActor.run { item.thumbnail = resized }
        }
    }

    /// Removes all entries from the thumbnail cache.
    func clearCache() {
        cache.removeAllObjects()
    }

    // MARK: - Private

    private func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }
}
