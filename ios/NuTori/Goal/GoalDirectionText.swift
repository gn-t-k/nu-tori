import NuToriAPI
import NuToriCore

/// 目標の向きの名前。「減量」「維持」「増量」
enum GoalDirectionText {
    static func name(_ direction: GoalSetupDirection) -> String {
        switch direction {
        case .lose: "減量"
        case .maintain: "維持"
        case .gain: "増量"
        }
    }

    static func name(_ direction: Goal.Direction) -> String {
        switch direction {
        case .lose: name(GoalSetupDirection.lose)
        case .maintain: name(GoalSetupDirection.maintain)
        case .gain: name(GoalSetupDirection.gain)
        }
    }
}
