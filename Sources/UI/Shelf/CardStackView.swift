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
                    .rotationEffect(.degrees(6.0))
                    .offset(x: 8, y: -4)
            }

            if items.count >= 2 {
                SingleCardLayer(item: items[1])
                    .rotationEffect(.degrees(-5.5))
                    .offset(x: -8, y: -2)
            }

            if let topItem = items.first {
                SingleCardLayer(item: topItem)
                    .rotationEffect(.degrees(0.5))
                    .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
            }
        }
        .frame(width: 110, height: 104)
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
                ZStack {
                    Color.white.opacity(0.96)

                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 52, height: 52)
                }
            }
        }
        .frame(width: 76, height: 90)
        .clipped()
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white, lineWidth: 3.0)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
}


