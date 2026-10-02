public import Foundation
public import NuToriAPI

/// 推定の状態の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct MealEstimationStatusSyncing: SyncedRecordKind {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.mealEstimationStatus

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    /// 取りに行った変更のうち、当てる今の状態（届いた順）と、消す状態の食事の ID
    public struct Current: Sendable, Equatable {
        public let statuses: [Status]
        public let removedMealIds: [UUID]
    }

    /// 食事1つの推定の状態
    public struct Status: Sendable, Equatable {
        public let mealId: UUID
        public let status: MealEstimationStatus
    }

    public init() {}

    /// 食事を消したときに、その食事の推定の状態を、削除の印と同じ形でキャッシュから消す変更
    static func removing(mealId: UUID) -> KindChanges {
        KindChanges(kind: kindName, changes: [.mealEstimationStatusDeletion(mealId: mealId)])
    }

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    /// 取りに行った変更を、今の状態の並びにする。食事より先に届いた状態も返す（届く順は約束しない）
    public func current(from changes: [SyncChange]) -> Current {
        var statuses: [Status] = []
        var removedMealIds: [UUID] = []
        for change in changes {
            if case .mealEstimationStatus(let synced) = change {
                statuses.append(
                    Status(mealId: synced.mealId, status: MealEstimationStatus(synced.status)))
            } else if case .mealEstimationStatusDeletion(let mealId) = change {
                removedMealIds.append(mealId)
            }
        }
        return Current(statuses: statuses, removedMealIds: removedMealIds)
    }
}

extension MealEstimationStatus {
    init(_ status: SyncedMealEstimationStatus.Status) {
        switch status {
        case .awaitingPhotos: self = .awaitingPhotos
        case .estimating: self = .estimating
        case .estimated: self = .estimated
        case .noDishes: self = .noDishes
        case .deferredToNextDay: self = .deferredToNextDay
        case .failed: self = .failed
        }
    }
}
