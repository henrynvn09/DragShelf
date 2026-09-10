import SwiftUI

// MARK: - ShelfHeaderView

struct ShelfHeaderView: View {

    // MARK: Properties

    @ObservedObject var store: ShelfStore
    @ObservedObject var actionEngine: BatchActionEngine
    var onClose: () -> Void

    // MARK: Body

    var body: some View {
        HStack(spacing: 8) {
            // Item count badge
            Text("\(store.items.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                )

            // Centered drag grip indicator
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 32, height: 4)

            Spacer()

            // Action menu (batch actions, share, copy paths)
            if !store.isEmpty {
                ShelfActionMenuView(store: store, actionEngine: actionEngine) { resultItems in
                    store.removeAll()
                    store.addItems(resultItems)
                }
            }

            // Pin toggle
            Button(action: {
                store.isPinned.toggle()
            }) {
                Image(systemName: store.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(store.isPinned ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .help(store.isPinned ? "Unpin shelf" : "Pin shelf")

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close shelf")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            WindowDragHandleView()
        )
    }
}

