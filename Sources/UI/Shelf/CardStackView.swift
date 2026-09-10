import SwiftUI
import AppKit

/// Renders staged items as a physical photo/card stack with crisp white borders
/// and subtle drop shadows, matching Dropover's authentic design.
struct CardStackView: View {
    let items: [StagedItem]

    var body: some View {
        ZStack {
            if items.count >= 3 {
                cardBacking(rotation: 4.5, offsetX: 5, offsetY: -3)
            }

            if items.count >= 2 {
                cardBacking(rotation: -3.5, offsetX: -5, offsetY: -2)
            }

            if let topItem = items.first {
                SingleCardLayer(item: topItem)
                    .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
            }
        }
        .frame(width: 105, height: 105)
    }

    private func cardBacking(rotation: Double, offsetX: CGFloat, offsetY: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white)
            .frame(width: 90, height: 90)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            .rotationEffect(.degrees(rotation))
            .offset(x: offsetX, y: offsetY)
    }
}

private struct SingleCardLayer: View {
    @ObservedObject var item: StagedItem

    var body: some View {
        ZStack {
            // White card base (polaroid/photo frame style)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white)

            // Inner image or file content with white margin padding
            if let thumb = item.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(3)
            } else {
                VStack(spacing: 4) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)

                    Text(item.title)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.black.opacity(0.75))
                        .padding(.horizontal, 4)
                }
                .frame(width: 80, height: 80)
            }
        }
        .frame(width: 90, height: 90)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
    }
}
