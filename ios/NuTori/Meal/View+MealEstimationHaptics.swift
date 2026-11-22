import NuToriCore
import SwiftUI

extension View {
    /// 待っていた食事の推定の結果が出た瞬間に、結果ごとの触覚を鳴らす。
    /// 推定は待ち時間があり、そのあいだ画面から目を離しがちなので、結果が出たことを手に伝える。推定できたときは、帯の丸がふくらむのと同時になる（#325）
    func mealEstimationHaptics(for meals: [MealCard]) -> some View {
        let progress = MealEstimationProgress(meals: meals)
        return
            haptic(.mealEstimated, trigger: progress) { old, new in
                new.hasEstimated(since: old)
            }
            .haptic(.mealEstimationFailed, trigger: progress) { old, new in
                new.hasFailed(since: old)
            }
            .haptic(.mealHadNoDishes, trigger: progress) { old, new in
                new.hasFoundNoDishes(since: old)
            }
    }
}
