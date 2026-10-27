import NuToriCore
import SwiftUI

/// 開いている料理が消えたら（この画面で消した、ほかの端末で消して同期で届いた）、食事の画面に戻る
struct DishDestination: View {
    /// 料理の画面に出す操作と、その料理の食事のカード（食事ごと消すときに渡す）
    let opened: (card: MealCard, offer: MealEditOffer.DishScreenOffer)?
    let screen: (MealCard, MealEditOffer.DishScreenOffer) -> DishScreen

    var body: some View {
        if let opened {
            screen(opened.card, opened.offer)
        } else {
            Color(.systemGroupedBackground)
                .onAppear {
                    dismiss()
                }
        }
    }

    @Environment(\.dismiss) private var dismiss
}
