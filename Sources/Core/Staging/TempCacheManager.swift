import Foundation

/// Manages a temporary file cache used to persist dropped content
/// (images, text, URLs) that doesn't already live on disk.
final class TempCacheManager {

    // MARK: - Singleton

    static let shared = TempCacheManager()

    // MARK: - Properties

    /// Root directory for cached files.
    let cacheDirectory: URL

    // MARK: - Init

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = base.appendingPathComponent("com.dropoverclone/temp", isDirectory: true)

        // Create the directory tree if it doesn't exist.
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Caching

    /// Writes raw image data to the cache and returns the resulting file URL.
    ///
    /// - Parameters:
    ///   - data: The image bytes to persist.
    ///   - suggestedName: An optional original filename. A UUID-based name
    ///     is used when `nil`.
    /// - Returns: The URL of the cached file, or `nil` on failure.
    func cacheImageData(_ data: Data, suggestedName: String?) -> URL? {
        let ext = suggestedName.flatMap { URL(fileURLWithPath: $0).pathExtension }
        let filename: String
        if let ext = ext, !ext.isEmpty {
            filename = "\(UUID().uuidString).\(ext)"
        } else {
            filename = "\(UUID().uuidString).png"
        }

        let dest = cacheDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: dest, options: .atomic)
            return dest
        } catch {
            print("[TempCacheManager] ⚠️ Failed to cache image data: \(error)")
            return nil
        }
    }

    /// Writes a text string to the cache as a `.txt` file.
    func cacheText(_ text: String) -> URL? {
        let filename = "\(UUID().uuidString).txt"
        let dest = cacheDirectory.appendingPathComponent(filename)
        do {
            try text.write(to: dest, atomically: true, encoding: .utf8)
            return dest
        } catch {
            print("[TempCacheManager] ⚠️ Failed to cache text: \(error)")
            return nil
        }
    }

    /// Creates a `.webloc` plist file for the given URL.
    func cacheURL(_ url: URL) -> URL? {
        let filename = "\(UUID().uuidString).webloc"
        let dest = cacheDirectory.appendingPathComponent(filename)
        let plist: [String: Any] = ["URL": url.absoluteString]
        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try data.write(to: dest, options: .atomic)
            return dest
        } catch {
            print("[TempCacheManager] ⚠️ Failed to cache URL: \(error)")
            return nil
        }
    }

    // MARK: - Removal

    /// Removes a single cached file, but only if it resides within the cache directory.
    func removeFile(at url: URL) {
        guard isInCache(url) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Deletes **all** files in the cache directory.
    func clearCache() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in contents {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Helpers

    /// Returns `true` if the given URL is located inside the cache directory.
    func isInCache(_ url: URL) -> Bool {
        return url.standardizedFileURL.path.hasPrefix(cacheDirectory.standardizedFileURL.path)
    }
}
