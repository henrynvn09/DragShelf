import SwiftUI
import AppKit

/// A SwiftUI view that presents a menu of batch actions for the shelf.
struct ShelfActionMenuView: View {
    @ObservedObject var store: ShelfStore
    @ObservedObject var actionEngine: BatchActionEngine

    /// Called when a batch action completes with the resulting items.
    var onActionComplete: (([StagedItem]) -> Void)?

    var body: some View {
        if actionEngine.isProcessing {
            ProgressView(value: actionEngine.progress)
                .progressViewStyle(.linear)
                .frame(width: 80)
                .padding(.horizontal, 4)
        } else {
            Menu {
                // Batch actions section
                let actions = actionEngine.availableActions(for: store.items)
                if !actions.isEmpty {
                    Section("Actions") {
                        ForEach(actions) { action in
                            Button {
                                actionEngine.execute(action, on: store.items) { [onActionComplete] resultItems in
                                    onActionComplete?(resultItems)
                                }
                            } label: {
                                Label(action.displayName, systemImage: action.systemImage)
                            }
                        }
                    }
                }

                Divider()

                // Share
                Button {
                    shareItems()
                } label: {
                    Label("Share...", systemImage: "square.and.arrow.up")
                }

                // Copy Paths
                Button {
                    copyPathsToClipboard()
                } label: {
                    Label("Copy Paths", systemImage: "doc.on.clipboard")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    // MARK: - Private

    /// Presents the macOS sharing picker using a temporary NSView anchor.
    private func shareItems() {
        // Find the key window to anchor the sharing picker
        guard let window = NSApp.keyWindow ?? NSApp.windows.first,
              let contentView = window.contentView
        else { return }

        SharingServiceBridge.share(
            items: store.items,
            relativeTo: contentView,
            preferredEdge: .minY
        )
    }

    /// Copies all file paths to the system clipboard.
    private func copyPathsToClipboard() {
        let paths = store.items.map(\.url.path).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths, forType: .string)
    }
}
