import NuToriAPI
import NuToriCore

/// 案の名前と、大変さのひとこと
enum GoalSetupDifficultyText {
    static func paceName(_ pace: GoalProposals.Pace) -> String {
        switch pace {
        case .gentle: "ゆるめ"
        case .standard: "標準"
        case .hard: "ハード"
        }
    }

    /// 1日の目安と推定消費カロリーの差から「推定消費カロリーより 400 kcal 少ない」（増量は「多い」）
    static func difference(_ kilocalories: Int) -> String {
        guard kilocalories != 0 else { return "推定消費カロリーと同じ" }
        let side = kilocalories < 0 ? "少ない" : "多い"
        return "推定消費カロリーより \(NutritionText.kilocalories(abs(kilocalories))) \(side)"
    }
}
