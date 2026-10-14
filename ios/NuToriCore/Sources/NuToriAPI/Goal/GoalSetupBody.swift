/// 推定消費カロリーを式で出すための身体データ。サーバーは保存しない
public struct GoalSetupBody: Sendable, Equatable {
    public let sex: Sex
    public let heightCentimeters: Double
    public let ageYears: Int
    public let activity: Activity

    public init(sex: Sex, heightCentimeters: Double, ageYears: Int, activity: Activity) {
        self.sex = sex
        self.heightCentimeters = heightCentimeters
        self.ageYears = ageYears
        self.activity = activity
    }

    public enum Sex: Sendable, Equatable {
        case male
        case female
    }

    public enum Activity: Sendable, Equatable {
        /// 初期値の窓の日（YYYY-MM-DD）ごとの歩数
        case steps([String: Int])
        /// 歩数が読めなかった人が選ぶ3択
        case level(Level)
    }

    public enum Level: Sendable, Equatable, CaseIterable {
        /// ほぼ座り仕事
        case sedentary
        /// 立ち仕事が多い
        case standing
        /// よく動く
        case active
    }
}
