import Foundation
import NuToriCore
import SwiftUI
import UIKit

/// タイムラインの食事のカード。写真を上に大きく出し、下に名前の場所（状態の1行）と時刻を置く。文章の食事は写真の場所を持たない。
/// カードの地と幅（`OwnRecordCard`）と、右に寄せるのは置く側が付ける。文章の食事は、下に「会話として送り直す」を添えた全体に付ける
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

    /// 推定が済んだ食事は、料理があれば料理の名前を、無ければ写真の推定の状態の1行を置く。推定を待っている食事は状態の1行だけを置く。
    /// 料理ごとの待ちの1行は付けない
    @ViewBuilder private var namePlace: some View {
        let place = card.namePlace
        if let dishNames = place.dishNames {
            Text(dishNames)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
        }
        if let statusLine = place.statusLine {
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

    /// kcal と P・F・C は、分かる料理があるときだけ出す。「不明」の材料が混じる栄養と、待っている料理がある食事の値には「以上」が付く
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
        card.eatenTimeText
    }

    private var accessibilityText: String {
        let nutrition = nutritionText.map { ([$0.kilocalories] + $0.pfc).joined(separator: " ") }
        let place = card.namePlace
        return ["食事", place.dishNames, place.statusLine, eatenTimeText, nutrition]
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
