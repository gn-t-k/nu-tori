#if DEBUG
    import SwiftUI

    #Preview("状態ごと", arguments: PickedPhotosLoadingCard.Sample.allCases) { sample in
        PickedPhotosLoadingCard(photoCount: sample.photoCount)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
            .background(Color(.systemGroupedBackground))
    }

    extension PickedPhotosLoadingCard {
        fileprivate enum Sample: CaseIterable {
            /// 1枚を選んだ。横長の枠が1つ
            case one
            /// 2枚を選んだ。正方形の枠が2つ
            case two
            /// 5枚を選んだ。2つめの枠に「+3」
            case five

            var photoCount: Int {
                switch self {
                case .one: 1
                case .two: 2
                case .five: 5
                }
            }
        }
    }
#endif
