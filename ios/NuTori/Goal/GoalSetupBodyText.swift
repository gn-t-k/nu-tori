import NuToriAPI

/// 身体データの性別と活動量の名前。足りない値のページと、目標案の上の1行で同じ名前にする
enum GoalSetupBodyText {
    static func sex(_ sex: GoalSetupBody.Sex) -> String {
        switch sex {
        case .male: "男性"
        case .female: "女性"
        }
    }

    static func level(_ level: GoalSetupBody.Level) -> String {
        switch level {
        case .sedentary: "ほぼ座り仕事"
        case .standing: "立ち仕事が多い"
        case .active: "よく動く"
        }
    }
}
