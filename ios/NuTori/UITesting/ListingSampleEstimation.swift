#if DEBUG
    import Foundation
    import NuToriAPI

    /// 見本の場面で、今日の食事をどこまで推定するか
    nonisolated enum ListingSampleEstimation {
        /// 写真の食事の推定を、時刻を直すまで終えない（推定を待つカードを撮るため）
        case waitsForCorrection
        /// 選んだ写真（LP のカレーライスの写真）の食事の推定を、次の取得で終える
        case estimatesPhoto
        /// LP の撮り忘れた食事の文（`site/src/pages/landing-a-page.tsx` の `forgottenMealText`）を食事と読み分け、推定を終える
        case estimatesText

        var estimatedDishes: @Sendable (UUID) -> [SyncChange] {
            switch self {
            case .waitsForCorrection: { _ in [] }
            case .estimatesPhoto:
                { mealId in ListingSampleDish.curry.changes(mealId: mealId) { _ in UUID() } }
            case .estimatesText:
                { mealId in ListingSampleDish.ochazuke.changes(mealId: mealId) { _ in UUID() } }
            }
        }

        var mealEstimation: FakeSyncServer.MealEstimation {
            switch self {
            case .waitsForCorrection: .afterEatenAtCorrected
            case .estimatesPhoto, .estimatesText: .afterPulls(1)
            }
        }

        var answerSentText: @Sendable (String) -> FakeSyncServer.SentTextAnswer? {
            switch self {
            case .waitsForCorrection, .estimatesPhoto: { _ in nil }
            case .estimatesText:
                { body in
                    let forgottenMealText = "朝はお茶漬けを食べた"
                    return body == forgottenMealText
                        ? .meal(replyAsConversation: "お茶漬けの話ですね。") : nil
                }
            }
        }
    }
#endif
