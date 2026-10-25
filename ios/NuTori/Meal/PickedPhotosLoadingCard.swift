import NuToriCore
import SwiftUI

/// 写真を選ぶ画面が閉じてから、選んだ写真を読み終えて食事のカードが出るまで、タイムラインの一番下に出す仮のカード。
/// 何を待っているか分かるよう、食事のカード（`MealCardView`）と同じ形で、写真の枠を選んだ枚数で決める。
/// いくつの食事に分かれるかは読み終えるまで決まらないので、1枚にまとめて出す
struct PickedPhotosLoadingCard: View {
    let photoCount: Int

    init(photoCount: Int) {
        self.photoCount = photoCount
        // 写真の ID は記録するときに振るので、ここでは枠の並べ方を決めるためだけの仮の ID を渡す
        photos = MealCard.Photos(photoIds: (0..<photoCount).map { _ in UUID() })
    }

    private let photos: MealCard.Photos

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photoPlace
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("写真を読み込んでいます…")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Text("\(photoCount)枚")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 大きな文字でも、状態の行を切らずに折り返す
            .fixedSize(horizontal: false, vertical: true)
            .padding()
        }
        .modifier(OwnRecordCard())
        // 届いていない食事のカード（`undeliveredRecord`）と同じ薄さにして、まだ記録の途中だと分かるようにする
        .opacity(0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("写真を読み込んでいます、\(photoCount)枚")
    }

    /// 食事のカードの写真の場所（`MealCardView`）と同じ並べ方で、写真の代わりに回る印を置く
    @ViewBuilder private var photoPlace: some View {
        switch photos {
        case .none:
            EmptyView()
        case .single:
            tile(aspectRatio: 4 / 3)
                .overlay { ProgressView() }
        case .pair(_, _, let remaining):
            HStack(spacing: 2) {
                tile(aspectRatio: 1)
                    .overlay { ProgressView() }
                tile(aspectRatio: 1)
                    .overlay {
                        if remaining > 0 {
                            Text("+\(remaining)")
                                .font(.title2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }

    private func tile(aspectRatio: CGFloat) -> some View {
        Color(.tertiarySystemFill)
            .aspectRatio(aspectRatio, contentMode: .fit)
    }
}
