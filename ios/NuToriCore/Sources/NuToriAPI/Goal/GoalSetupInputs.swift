public import Foundation

/// 目標の設定の4つの要求に共通して載せる値。サーバーは保存しない
public struct GoalSetupInputs: Sendable, Equatable {
    /// 端末の今のタイムゾーン。開始の日を決める
    public let timeZone: TimeZone
    /// 初めての目標のときだけ添える、使い始める前の日（YYYY-MM-DD）ごとの摂取エネルギー（kcal）。立て直しは nil
    public let preUseEnergyIntakes: [String: Double]?
    /// 初めての目標で逆算できない人が、足りない値を入れたあとに添える
    public let body: GoalSetupBody?

    public init(timeZone: TimeZone, preUseEnergyIntakes: [String: Double]?, body: GoalSetupBody?) {
        self.timeZone = timeZone
        self.preUseEnergyIntakes = preUseEnergyIntakes
        self.body = body
    }
}
