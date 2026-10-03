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
                    if let nutritionText {
                        ItemWrappingLayout(spacing: 8, lineSpacing: 0) {
                            Text(nutritionText.kilocalories).fontWeight(.semibold)
                            ForEach(nutritionText.pfc, id: \.self) { Text($0) }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // 大きな文字でも、名前と状態の行を切らずに折り返す
                .fixedSize(horizontal: false, vertical: true)
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
            let widthRatio: CGFloat = 0.72
            return width * widthRatio
        }
        .modifier(
            MealPhotosLoading(
                photoIds: shownPhotoIds, state: card.state, images: $images, loadPhoto: loadPhoto)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// 読み終えた写真。写真をまだ持っていない端末では、届くまで回る印を出す
    @State private var images: [UUID: UIImage] = [:]

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
    /// 推定できた食事は料理の名前を置く（料理がまだ届いていなければ、届くまで何も置かない）
    @ViewBuilder private var namePlace: some View {
        if let dishNames {
            Text(dishNames)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
        } else if let statusLine = card.state.statusLine {
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

    /// 推定できて、料理が届いている食事の名前
    private var dishNames: String? {
        guard case .estimated = card.nutrition else { return nil }
        return card.contents.name
    }

    /// kcal と P・F・C は、推定できたときだけ出す。「不明」の材料が混じる栄養には「以上」が付く
    private var nutritionText: (kilocalories: String, pfc: [String])? {
        guard case .estimated(let totals) = card.nutrition else { return nil }
        let pfc = PFC.allCases.map { pfc in
            "\(pfc.letter) \(NutritionText.amount(totals[pfc.nutrient], of: pfc.nutrient))"
        }
        return (NutritionText.amount(totals[.energyKcal], of: .energyKcal), pfc)
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
        let nutrition = nutritionText.map { ([$0.kilocalories] + $0.pfc).joined(separator: " ") }
        return ["食事", dishNames ?? card.state.statusLine, eatenTimeText, nutrition]
            .compactMap(\.self).joined(separator: "、")
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
            // clipped は見た目だけを切り抜く。枠からはみ出した写真が、上下の行を押したのを取らないよう、押せる所も枠に合わせる
            .contentShape(Rectangle())
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
}
