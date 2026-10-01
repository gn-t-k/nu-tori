import Foundation
import NuToriCore
import SwiftUI
import UIKit

/// タイムラインの食事のカード。自分の記録として Primary を薄く敷き、画面の幅の 72% にする。
/// 写真を上に大きく出し、下に名前の場所（状態の1行）と時刻を置く。右に寄せるのは置く側
struct MealCardView: View {
    let card: MealCard
    /// カードに描く大きさに縮めた写真。この端末に無ければ取りに行く。取れなければ nil
    let loadPhoto: (_ photoId: UUID) async -> UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photos
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    namePlace
                    Text(eatenTimeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding()
        }
        // DESIGN.md の own-record-card。Surface に Primary を 10% 混ぜる。角はタイムラインのカード（12）
        .background(Color.accentColor.opacity(0.1))
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .containerRelativeFrame(.horizontal) { width, _ in
            width * Self.widthRatio
        }
        .task(id: PhotoRequest(photoIds: shownPhotoIds, state: card.state)) {
            await loadPhotos()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("meal-card")
    }

    private static let widthRatio: CGFloat = 0.72

    /// 読み終えた写真。写真をまだ持っていない端末では、届くまで回る印を出す
    @State private var images: [UUID: UIImage] = [:]

    /// 写真がサーバーに届くと推定の状態が変わるので、状態が変わったら取りに行き直す
    private struct PhotoRequest: Equatable {
        let photoIds: [UUID]
        let state: MealCardState
    }

    @ViewBuilder private var photos: some View {
        switch card.photos {
        case .none:
            EmptyView()
        case .single(let photoId):
            photoTile(photoId, aspectRatio: 4 / 3)
        case .pair(let first, let second, let remaining):
            HStack(spacing: 2) {
                photoTile(first, aspectRatio: 1)
                photoTile(second, aspectRatio: 1)
                    .overlay {
                        if remaining > 0 {
                            remainingCount(remaining)
                        }
                    }
            }
        }
    }

    /// まだ送れていない・写真を待っているあいだは、何も置かない（写真と時刻だけ）。
    /// 推定できた食事の料理の名前と kcal・P・F・C は、料理が端末に届くようになってから置く
    @ViewBuilder private var namePlace: some View {
        if let statusLine = card.state.statusLine {
            HStack(spacing: 6) {
                // 推定の待っている表示。サーバーが処理しているあいだだけ出す
                if card.state == .estimating {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(statusLine)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var shownPhotoIds: [UUID] {
        switch card.photos {
        case .none: []
        case .single(let photoId): [photoId]
        case .pair(let first, let second, _): [first, second]
        }
    }

    private var eatenTimeText: String {
        switch card.eatenTime {
        case .clock(let clock):
            WeightAmountText.clock(clock)
        case .dayAndClock(let day, let clock):
            "\(TimelineDayText.label(for: day))\(WeightAmountText.clock(clock))"
        }
    }

    private var accessibilityText: String {
        ["食事", card.state.statusLine, eatenTimeText].compactMap(\.self).joined(separator: "、")
    }

    /// 写真の場所は先に Fill で大きさを決め、写真はその枠いっぱいに切り抜く。届くまでは回る印を出す
    private func photoTile(_ photoId: UUID, aspectRatio: CGFloat) -> some View {
        Color(.tertiarySystemFill)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                if let image = images[photoId] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private func remainingCount(_ remaining: Int) -> some View {
        ZStack {
            Color.black.opacity(0.4)
            Text("+\(remaining)")
                .font(.title2)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }

    private func loadPhotos() async {
        for photoId in shownPhotoIds where images[photoId] == nil {
            if let image = await loadPhoto(photoId) {
                images[photoId] = image
            }
        }
    }
}
