public import Foundation
public import NuToriAPI

/// 料理ごとの推定の状態の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct DishEstimationStatusSyncing: SyncedRecordKind {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.dishEstimationStatus

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    /// 取りに行った変更のうち、当てる今の状態（届いた順）と、消す状態の料理の ID
    public struct Current: Sendable, Equatable {
        public let statuses: [Status]
        public let removedDishIds: [UUID]
    }

    /// 料理1つの推定の状態
    public struct Status: Sendable, Equatable {
        public let dishId: UUID
        public let status: DishEstimationStatus
    }

    public init() {}

    /// 料理を消したときに、その料理の推定の状態を、削除の印と同じ形でキャッシュから消す変更
    static func removing(dishId: UUID) -> KindChanges {
        KindChanges(kind: kindName, changes: [.dishEstimationStatusDeletion(dishId: dishId)])
    }

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    /// 取りに行った変更を、今の状態の並びにする。料理より先に届いた状態も返す（届く順は約束しない）
    public func current(from changes: [SyncChange]) -> Current {
        var statuses: [Status] = []
        var removedDishIds: [UUID] = []
        for change in changes {
            if case .dishEstimationStatus(let synced) = change {
                statuses.append(
                    Status(dishId: synced.dishId, status: DishEstimationStatus(synced.status)))
            } else if case .dishEstimationStatusDeletion(let dishId) = change {
                removedDishIds.append(dishId)
            }
        }
        return Current(statuses: statuses, removedDishIds: removedDishIds)
    }
}

extension DishEstimationStatus {
    init(_ status: SyncedDishEstimationStatus.Status) {
        switch status {
        case .estimating: self = .estimating
        case .deferredToNextDay: self = .deferredToNextDay
        case .estimated: self = .estimated
        case .noDishes: self = .noDishes
        case .failed: self = .failed
        }
    }
}
