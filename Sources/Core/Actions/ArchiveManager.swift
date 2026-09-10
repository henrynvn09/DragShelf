import Foundation

/// Manages zip compression and decompression via system utilities.
final class ArchiveManager {

    // MARK: - Compress

    /// Compresses the given file URLs into a single zip archive.
    /// Returns the URL of the created archive, or nil on failure.
    static func compressItems(
        _ urls: [URL],
        archiveName: String = "Archive",
        outputDirectory: URL
    ) -> URL? {
        guard !urls.isEmpty else { return nil }

        let archiveURL = outputDirectory
            .appendingPathComponent(archiveName)
            .appendingPathExtension("zip")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")

        // Build arguments: -j to junk (don't record) directory paths
        var arguments = ["-j", archiveURL.path]
        arguments.append(contentsOf: urls.map(\.path))
        process.arguments = arguments

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        guard FileManager.default.fileExists(atPath: archiveURL.path) else { return nil }

        return archiveURL
    }

    // MARK: - Decompress

    /// Decompresses a zip archive to the given output directory.
    /// Returns the list of extracted file URLs, or nil on failure.
    static func decompressArchive(at url: URL, outputDirectory: URL) -> [URL]? {
        // Ensure output directory exists
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", url.path, "-d", outputDirectory.path]

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        // Enumerate extracted files
        let enumerator = FileManager.default.enumerator(
            at: outputDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var extractedURLs: [URL] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
               values.isRegularFile == true {
                extractedURLs.append(fileURL)
            }
        }

        return extractedURLs.isEmpty ? nil : extractedURLs
    }
}
