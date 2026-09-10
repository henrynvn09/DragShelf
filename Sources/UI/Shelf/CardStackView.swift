import SwiftUI
import AppKit

/// Renders staged items as a physical photo/card stack with white borders
/// and subtle drop shadows, matching DragShelf's iconic design.
struct CardStackView: View {
    let items: [StagedItem]

    var body: some View {
        ZStack {
            if items.count >= 3 {
                SingleCardLayer(item: items[2])
                    .rotationEffect(.degrees(5.5))
                    .offset(x: 7, y: -4)
            }

            if items.count >= 2 {
                SingleCardLayer(item: items[1])
                    .rotationEffect(.degrees(-5.0))
                    .offset(x: -7, y: -2)
            }

            if let topItem = items.first {
                SingleCardLayer(item: topItem)
                    .rotationEffect(.degrees(0.5))
                    .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
            }
        }
        .frame(width: 105, height: 100)
    }
}

private struct SingleCardLayer: View {
    @ObservedObject var item: StagedItem

    var body: some View {
        Group {
            if let thumb = item.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                VStack(spacing: 3) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)

                    Text(item.title)
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.95))
            }
        }
        .frame(width: 72, height: 86)
        .clipped()
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.white, lineWidth: 2.5)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 2)
    }
}

