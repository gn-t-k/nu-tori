import Foundation
import NuToriCore
import SwiftData

/// いつもの時刻。アカウントに1つなので、行は1つだけ置く
@Model
nonisolated final class CachedUsualWeighingTime {
    @Attribute(.unique) var singletonKey: String
    var usualWeighingTimeId: UUID
    /// その日の何分目
    var minuteOfDay: Int

    init(_ usualWeighingTime: UsualWeighingTime) {
        singletonKey = Self.onlyKey
        // 値は apply が入れる。欄をすべて埋めるまで apply を呼べない（Swift の init の決まり）ので、省けない欄に仮の値を入れる
        usualWeighingTimeId = UUID()
        minuteOfDay = 0
        apply(usualWeighingTime)
    }

    func apply(_ usualWeighingTime: UsualWeighingTime) {
        usualWeighingTimeId = usualWeighingTime.id
        minuteOfDay = usualWeighingTime.minuteOfDay
    }

    func usualWeighingTime() -> UsualWeighingTime {
        UsualWeighingTime(id: usualWeighingTimeId, minuteOfDay: minuteOfDay)
    }

    static let onlyKey = "usual-weighing-time"
}
