import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - ShelfContainerView

struct ShelfContainerView: View {

    // MARK: Properties

    @ObservedObject var store: ShelfStore
    @StateObject private var actionEngine = BatchActionEngine()
    var onClose: () -> Void

    @State private var isDropTargeted: Bool = false

    // MARK: Body

    var body: some View {
        ZStack {
            // Layer 1: Full-window drag handle (moves shelf everywhere except on active controls & card stack)
            WindowDragHandleView()

            // Layer 2: Sleek Dark Slate Card Background (matching reference Image 2)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.23, green: 0.25, blue: 0.26))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            isDropTargeted ? Color.accentColor : Color.white.opacity(0.14),
                            lineWidth: isDropTargeted ? 2.0 : 1.0
                        )
                )
                .allowsHitTesting(false) // Allows clicks outside controls to hit WindowDragHandleView

            // Layer 3: Interactive Content
            VStack(spacing: 0) {
                // Top Bar
                topBarView
                    .frame(height: 26)

                Spacer(minLength: 4)

                // Middle Region: ONLY this center area where files show is for dragging files!
                if store.isEmpty {
                    emptyStateDropZone
                } else {
                    centerCardStackRegion
                }

                Spacer(minLength: 4)

                // Bottom: Capsule Count / Filename Badge (or spacer when empty)
                if !store.isEmpty {
                    countCapsuleBadge
                        .padding(.bottom, 2)
                } else {
                    Spacer().frame(height: 12)
                }
            }
            .padding(12)
        }
        .frame(width: 175, height: 185)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onDrop(of: [.fileURL, .url, .image, .plainText, .tiff, .png], isTargeted: $isDropTargeted) { providers in
            // Guard: Never accept drops back into ourselves while dragging out!
            guard !DragAllNSView.isDraggingOutActive else { return false }
            handleDrop(providers: providers)
            return true
        }
    }

    // MARK: - Top Bar

    private var topBarView: some View {
        HStack(spacing: 6) {
            closeButton

            Spacer() // Clicks pass through to WindowDragHandleView to move the shelf!

            actionMenuButton
        }
    }

    // MARK: - Middle File Region (ONLY region that drags files)

    private var centerCardStackRegion: some View {
        CardStackView(items: store.items)
            .frame(width: 105, height: 105)
            .overlay(
                DragAllRepresentable(
                    items: store.items,
                    onDropFiles: { urls in
                        handleDroppedURLs(urls)
                    },
                    onDragCompleted: {
                        if !store.isPinned {
                            store.removeAll()
                        }
                    }
                )
            )
    }

    // MARK: - Empty State Drop Zone

    private var emptyStateDropZone: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Color.white.opacity(0.6))

            Text("Drop files here")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.8))

            Text("or shake while dragging")
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 95)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                )
        )
    }

    // MARK: - Buttons & Controls

    /// Light circular close button with dark icon (matching reference Image 2)
    private var closeButton: some View {
        Button(action: onClose) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.72).opacity(0.85))
                    .frame(width: 26, height: 26)
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Color(white: 0.18))
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Dismiss Shelf")
    }

    /// Light circular 3-dots action menu button with dark icon (matching reference Image 2)
    private var actionMenuButton: some View {
        Menu {
            if store.isEmpty {
                Button {
                    ShelfCoordinator.shared.spawnShelfAtCursor()
                } label: {
                    Label("New Shelf", systemImage: "plus.rectangle.on.rectangle")
                }

                Divider()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit Dropover", systemImage: "power")
                }
            } else {
                Button {
                    QuickLookController.shared.togglePreview(for: store.items)
                } label: {
                    Label("Open with Preview", systemImage: "eye")
                }

                Button {
                    if let first = store.items.first {
                        NSWorkspace.shared.activateFileViewerSelecting([first.url])
                    }
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }

                Divider()

                Button {
                    shareItems()
                } label: {
                    Label("Share...", systemImage: "square.and.arrow.up")
                }

                Divider()

                let actions = actionEngine.availableActions(for: store.items)
                if !actions.isEmpty {
                    Section("Actions") {
                        ForEach(actions) { action in
                            Button {
                                actionEngine.execute(action, on: store.items) { resultItems in
                                    store.removeAll()
                                    store.addItems(resultItems)
                                }
                            } label: {
                                Label(action.displayName, systemImage: action.systemImage)
                            }
                        }
                    }
                    Divider()
                }

                Button {
                    copyPathsToClipboard()
                } label: {
                    Label("Copy Paths", systemImage: "doc.on.clipboard")
                }

                Button(role: .destructive) {
                    store.removeAll()
                } label: {
                    Label("Clear All Items", systemImage: "trash")
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(white: 0.72).opacity(0.85))
                    .frame(width: 26, height: 26)
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Color(white: 0.18))
            }
            .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Actions Menu")
    }

    /// Frosted capsule badge showing filename / count + light circular chevron (matching Image 2)
    private var countCapsuleBadge: some View {
        Button {
            QuickLookController.shared.togglePreview(for: store.items)
        } label: {
            HStack(spacing: 6) {
                Text(badgeLabelText(for: store.items))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 110, alignment: .leading)

                ZStack {
                    Circle()
                        .fill(Color(white: 0.72).opacity(0.85))
                        .frame(width: 16, height: 16)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(Color(white: 0.18))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4.5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help("Click to Quick Look Preview")
    }

    // MARK: - Helpers

    private func badgeLabelText(for items: [StagedItem]) -> String {
        guard !items.isEmpty else { return "0 Items" }

        // If single item, show the file name (matching Image 2: "Screen S...PM.png")
        if items.count == 1, let first = items.first {
            return first.title
        }

        let count = items.count
        let isAllImages = items.allSatisfy { item in
            let ext = item.url.pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "gif", "heic", "tiff", "webp", "bmp"].contains(ext)
                || item.kind == .webImage
        }
        if isAllImages {
            return "\(count) Images"
        }

        let isAllFiles = items.allSatisfy { $0.kind == .file }
        if isAllFiles {
            return "\(count) Files"
        }

        return "\(count) Items"
    }

    private func shareItems() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first,
              let contentView = window.contentView else { return }
        SharingServiceBridge.share(items: store.items, relativeTo: contentView, preferredEdge: .minY)
    }

    private func copyPathsToClipboard() {
        let paths = store.items.map(\.url.path).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths, forType: .string)
    }

    private func handleDroppedURLs(_ urls: [URL]) {
        for url in urls {
            guard !store.containsURL(url) else {
                NSLog("[ShelfContainer] ⚠️ Duplicate URL ignored: %@", url.lastPathComponent)
                continue
            }
            let item = StagedItem(
                url: url,
                kind: .file,
                title: url.lastPathComponent,
                fileSize: Self.fileSizeForURL(url)
            )
            store.addItem(item)
            Task {
                await ThumbnailManager.shared.generateThumbnail(
                    for: item,
                    size: CGSize(width: 160, height: 180)
                )
            }
        }
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    guard !store.containsURL(url) else {
                        NSLog("[ShelfContainer] ⚠️ Duplicate drop ignored: %@", url.lastPathComponent)
                        return
                    }
                    let title = url.lastPathComponent
                    let size = Self.fileSizeForURL(url)
                    let item = StagedItem(url: url, kind: .file, title: title, fileSize: size)
                    DispatchQueue.main.async {
                        store.addItem(item)
                    }
                    Task {
                        await ThumbnailManager.shared.generateThumbnail(
                            for: item,
                            size: CGSize(width: 160, height: 180)
                        )
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          !url.isFileURL else { return }
                    guard !store.containsURL(url) else { return }
                    if let cached = TempCacheManager.shared.cacheURL(url) {
                        let item = StagedItem(url: cached, kind: .url, title: url.absoluteString, fileSize: nil)
                        DispatchQueue.main.async {
                            store.addItem(item)
                        }
                        Task {
                            await ThumbnailManager.shared.generateThumbnail(
                                for: item,
                                size: CGSize(width: 160, height: 180)
                            )
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data = data,
                          let cached = TempCacheManager.shared.cacheImageData(data, suggestedName: nil) else { return }
                    let item = StagedItem(url: cached, kind: .webImage, title: cached.lastPathComponent, fileSize: Int64(data.count))
                    DispatchQueue.main.async {
                        store.addItem(item)
                    }
                    Task {
                        await ThumbnailManager.shared.generateThumbnail(
                            for: item,
                            size: CGSize(width: 160, height: 180)
                        )
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                    let text: String?
                    if let str = data as? String {
                        text = str
                    } else if let d = data as? Data {
                        text = String(data: d, encoding: .utf8)
                    } else {
                        text = nil
                    }
                    guard let text = text, !text.isEmpty,
                          let cached = TempCacheManager.shared.cacheText(text) else { return }
                    let title = String(text.prefix(60))
                    let item = StagedItem(url: cached, kind: .textClipping, title: title, fileSize: Int64(text.utf8.count))
                    DispatchQueue.main.async {
                        store.addItem(item)
                    }
                    Task {
                        await ThumbnailManager.shared.generateThumbnail(
                            for: item,
                            size: CGSize(width: 160, height: 180)
                        )
                    }
                }
            }
        }
    }

    private static func fileSizeForURL(_ url: URL) -> Int64? {
        guard url.isFileURL else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int64
    }
}
