import SwiftUI

// MARK: - StagedItemCardView

struct StagedItemCardView: View {

    // MARK: Properties

    @ObservedObject var item: StagedItem
    var onRemove: () -> Void

    @State private var isHovered: Bool = false

    // MARK: Body

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            thumbnailView
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            // Title and file size
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !item.formattedFileSize.isEmpty {
                    Text(item.formattedFileSize)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 4)

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail = item.thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: iconForKind(item.kind))
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.05))
        }
    }

    // MARK: Helpers

    private func iconForKind(_ kind: StagedItemKind) -> String {
        switch kind {
        case .file:
            return "folder.fill"
        case .webImage:
            return "photo"
        case .url:
            return "link"
        case .textClipping:
            return "doc.text"
        }
    }
}
