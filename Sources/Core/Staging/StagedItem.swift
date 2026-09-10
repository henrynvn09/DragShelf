import AppKit
import Combine

// MARK: - StagedItemKind

enum StagedItemKind: String, Codable {
    case file
    case webImage
    case url
    case textClipping
}

// MARK: - StagedItem

final class StagedItem: Identifiable, ObservableObject, Hashable {

    // MARK: Properties

    let id: UUID
    let url: URL
    let kind: StagedItemKind
    let title: String
    let fileSize: Int64?
    let createdAt: Date

    @Published var thumbnail: NSImage?

    // MARK: Initialization

    init(
        id: UUID = UUID(),
        url: URL,
        kind: StagedItemKind,
        title: String,
        fileSize: Int64? = nil,
        thumbnail: NSImage? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.kind = kind
        self.title = title
        self.fileSize = fileSize
        self.thumbnail = thumbnail
        self.createdAt = createdAt
    }

    // MARK: Formatted File Size

    var formattedFileSize: String {
        guard let size = fileSize else { return "" }

        let units: [(String, Int64)] = [
            ("GB", 1_073_741_824),
            ("MB", 1_048_576),
            ("KB", 1_024),
        ]

        for (suffix, threshold) in units {
            if size >= threshold {
                let value = Double(size) / Double(threshold)
                return String(format: "%.1f %@", value, suffix)
            }
        }
        return "\(size) B"
    }

    // MARK: Hashable

    static func == (lhs: StagedItem, rhs: StagedItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
