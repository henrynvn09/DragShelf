import Foundation
import Combine

/// Coordinates batch operations on collections of staged items.
final class BatchActionEngine: ObservableObject {

    // MARK: - Published State

    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0.0

    // MARK: - BatchAction

    enum BatchAction: String, CaseIterable, Identifiable {
        case convertToJPEG
        case convertToPNG
        case resizeTo50Percent
        case stripMetadata
        case recognizeText
        case compressToZip

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .convertToJPEG:    return "Convert to JPEG"
            case .convertToPNG:     return "Convert to PNG"
            case .resizeTo50Percent: return "Resize to 50%"
            case .stripMetadata:    return "Strip Metadata"
            case .recognizeText:    return "Recognize Text (OCR)"
            case .compressToZip:    return "Compress to ZIP"
            }
        }

        var systemImage: String {
            switch self {
            case .convertToJPEG:    return "photo"
            case .convertToPNG:     return "photo.fill"
            case .resizeTo50Percent: return "arrow.down.right.and.arrow.up.left"
            case .stripMetadata:    return "eye.slash"
            case .recognizeText:    return "doc.text.viewfinder"
            case .compressToZip:    return "archivebox"
            }
        }
    }

    // MARK: - Available Actions

    /// Returns the batch actions relevant to the given collection of items.
    func availableActions(for items: [StagedItem]) -> [BatchAction] {
        guard !items.isEmpty else { return [] }

        let hasImages = items.contains { item in
            let ext = item.url.pathExtension.lowercased()
            return ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "gif", "webp"].contains(ext)
                || item.kind == .webImage
        }

        var actions: [BatchAction] = []

        if hasImages {
            actions.append(contentsOf: [
                .convertToJPEG,
                .convertToPNG,
                .resizeTo50Percent,
                .stripMetadata,
                .recognizeText,
            ])
        }

        // Zip is always available when there are items
        actions.append(.compressToZip)

        return actions
    }

    // MARK: - Execute

    /// Executes a batch action on the given items, reporting progress
    /// and calling completion with the replacement items.
    func execute(
        _ action: BatchAction,
        on items: [StagedItem],
        completion: @escaping ([StagedItem]) -> Void
    ) {
        guard !items.isEmpty else {
            completion([])
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.isProcessing = true
            self?.progress = 0.0
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outputDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("Dropover-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

            var resultItems: [StagedItem] = []
            let total = Double(items.count)

            switch action {
            case .convertToJPEG:
                for (i, item) in items.enumerated() {
                    if let url = ImageProcessor.convertImage(at: item.url, to: .jpeg, outputDirectory: outputDirectory) {
                        resultItems.append(Self.makeStagedItem(from: url))
                    } else {
                        resultItems.append(item)
                    }
                    self?.updateProgress(Double(i + 1) / total)
                }

            case .convertToPNG:
                for (i, item) in items.enumerated() {
                    if let url = ImageProcessor.convertImage(at: item.url, to: .png, outputDirectory: outputDirectory) {
                        resultItems.append(Self.makeStagedItem(from: url))
                    } else {
                        resultItems.append(item)
                    }
                    self?.updateProgress(Double(i + 1) / total)
                }

            case .resizeTo50Percent:
                for (i, item) in items.enumerated() {
                    if let url = ImageProcessor.resizeImage(at: item.url, scale: 0.5, outputDirectory: outputDirectory) {
                        resultItems.append(Self.makeStagedItem(from: url))
                    } else {
                        resultItems.append(item)
                    }
                    self?.updateProgress(Double(i + 1) / total)
                }

            case .stripMetadata:
                for (i, item) in items.enumerated() {
                    if let url = ImageProcessor.stripMetadata(at: item.url, outputDirectory: outputDirectory) {
                        resultItems.append(Self.makeStagedItem(from: url))
                    } else {
                        resultItems.append(item)
                    }
                    self?.updateProgress(Double(i + 1) / total)
                }

            case .recognizeText:
                let group = DispatchGroup()
                let lock = NSLock()
                for (i, item) in items.enumerated() {
                    group.enter()
                    TextRecognizer.recognizeText(in: item.url) { text in
                        if let text = text, !text.isEmpty {
                            // Create a text clipping file with the recognized text
                            let textFileURL = outputDirectory
                                .appendingPathComponent(item.url.deletingPathExtension().lastPathComponent + "_ocr")
                                .appendingPathExtension("txt")
                            try? text.write(to: textFileURL, atomically: true, encoding: .utf8)
                            lock.lock()
                            resultItems.append(Self.makeStagedItem(from: textFileURL, kind: .textClipping))
                            lock.unlock()
                        }
                        self?.updateProgress(Double(i + 1) / total)
                        group.leave()
                    }
                }
                group.wait()

            case .compressToZip:
                let urls = items.map(\.url)
                if let archiveURL = ArchiveManager.compressItems(urls, outputDirectory: outputDirectory) {
                    resultItems.append(Self.makeStagedItem(from: archiveURL))
                }
                self?.updateProgress(1.0)
            }

            DispatchQueue.main.async {
                self?.isProcessing = false
                self?.progress = 1.0
                completion(resultItems)
            }
        }
    }

    // MARK: - Private

    private func updateProgress(_ value: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.progress = value
        }
    }

    /// Creates a new StagedItem from a result URL, inferring kind and title.
    private static func makeStagedItem(from url: URL, kind: StagedItemKind = .file) -> StagedItem {
        let title = url.lastPathComponent
        let fileSize: Int64? = {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int64 else { return nil }
            return size
        }()
        return StagedItem(url: url, kind: kind, title: title, fileSize: fileSize)
    }
}
