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

            // Layer 2: Clean, single-surface Black Theme Card (no double margin)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.09).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isDropTargeted ? Color.accentColor : Color.white.opacity(0.16),
                            lineWidth: isDropTargeted ? 2.0 : 1.0
                        )
                )
                .allowsHitTesting(false) // Allows clicks outside controls to hit WindowDragHandleView

            // Layer 3: Interactive Content
            VStack(spacing: 0) {
                // Top Bar
                topBarView
                    .frame(height: 24)

                Spacer(minLength: 4)

                // Middle Region: ONLY this center area where files show is for dragging files!
                if store.isEmpty {
                    emptyStateDropZone
                } else {
                    centerCardStackRegion
                }

                Spacer(minLength: 4)

                // Bottom: Capsule Count Badge (or spacer when empty)
                if !store.isEmpty {
                    countCapsuleBadge
                        .padding(.bottom, 2)
                } else {
                    Spacer().frame(height: 12)
                }
            }
            .padding(10)
        }
        .frame(width: 165, height: 175)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .frame(height: 26)
    }

    // MARK: - Middle File Region (ONLY region that drags files)

    private var centerCardStackRegion: some View {
        CardStackView(items: store.items)
            .frame(width: 105, height: 100)
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
                .foregroundStyle(Color.white.opacity(0.55))

            Text("Drop files here")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.75))

            Text("or shake while dragging")
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.38))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                )
        )
    }

    // MARK: - Buttons & Controls

    /// Circular close button (top left)
    private var closeButton: some View {
        Button(action: onClose) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.38))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    )
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Dismiss Shelf")
    }

    /// Circular 3-dots action menu button (top right)
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
                    .fill(Color(white: 0.38))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    )
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Actions Menu")
    }

    /// Dark capsule count badge (e.g. "5 Images ⌵")
    private var countCapsuleBadge: some View {
        Button {
            QuickLookController.shared.togglePreview(for: store.items)
        } label: {
            HStack(spacing: 4) {
                Text(countBadgeText(for: store.items))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))

                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 3.5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(white: 0.18).opacity(0.88))
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

    private func countBadgeText(for items: [StagedItem]) -> String {
        let count = items.count
        guard count > 0 else { return "0 Items" }

        let isAllImages = items.allSatisfy { item in
            let ext = item.url.pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "gif", "heic", "tiff", "webp", "bmp"].contains(ext)
                || item.kind == .webImage
        }
        if isAllImages {
            return count == 1 ? "1 Image" : "\(count) Images"
        }

        let isAllFiles = items.allSatisfy { $0.kind == .file }
        if isAllFiles {
            return count == 1 ? "1 File" : "\(count) Files"
        }

        return count == 1 ? "1 Item" : "\(count) Items"
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
