import NuToriCore
import SwiftUI

/// 開いている料理が消えたら（この画面で消した、ほかの端末で消して同期で届いた）、食事の画面に戻る
struct DishDestination: View {
    let offer: MealEditOffer.DishScreenOffer?
    let screen: (MealEditOffer.DishScreenOffer) -> DishScreen

    var body: some View {
        if let offer {
            screen(offer)
        } else {
            Color(.systemGroupedBackground)
                .onAppear {
                    dismiss()
                }
        }
    }

    @Environment(\.dismiss) private var dismiss
}
