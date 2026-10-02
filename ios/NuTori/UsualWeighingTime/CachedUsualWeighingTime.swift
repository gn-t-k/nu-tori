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
        usualWeighingTimeId = usualWeighingTime.id
        minuteOfDay = usualWeighingTime.minuteOfDay
    }

    func apply(_ usualWeighingTime: UsualWeighingTime) {
        usualWeighingTimeId = usualWeighingTime.id
        minuteOfDay = usualWeighingTime.minuteOfDay
    }

    func usualWeighingTime() -> UsualWeighingTime {
        UsualWeighingTime(id: usualWeighingTimeId, minuteOfDay: minuteOfDay)
    }

    /// 保存は呼び出し側が行う
    static func write(_ usualWeighingTime: UsualWeighingTime, in context: ModelContext) throws {
        if let existing = try current(in: context) {
            existing.apply(usualWeighingTime)
        } else {
            context.insert(CachedUsualWeighingTime(usualWeighingTime))
        }
    }

    static func current(in context: ModelContext) throws -> CachedUsualWeighingTime? {
        let key = onlyKey
        var descriptor = FetchDescriptor<CachedUsualWeighingTime>(
            predicate: #Predicate { $0.singletonKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    static let onlyKey = "usual-weighing-time"
}
