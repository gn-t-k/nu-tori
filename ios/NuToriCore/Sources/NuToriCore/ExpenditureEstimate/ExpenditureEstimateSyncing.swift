public import Foundation
public import NuToriAPI

/// 推定消費カロリーの同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct ExpenditureEstimateSyncing: CacheApplying {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.expenditureEstimate

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    /// 届いた順に推定を書く。推定は消えない
    public func apply(
        _ changes: [SyncChange], to cache: any KeyedRecordCache<ExpenditureEstimate, UUID>
    ) throws {
        for estimate in current(from: changes) {
            try cache.upsert(estimate)
        }
    }

    public func erase(_ cache: any KeyedRecordCache<ExpenditureEstimate, UUID>) throws {
        try cache.removeAll()
    }

    /// 取りに行った変更を、今の値の並び（届いた順）にする。当てる始まりの日が読めない推定は読み飛ばす
    public func current(from changes: [SyncChange]) -> [ExpenditureEstimate] {
        changes.compactMap { change in
            guard case .expenditureEstimate(let synced) = change else { return nil }
            return ExpenditureEstimate(synced)
        }
    }
}

extension ExpenditureEstimate {
    /// 当てる始まりの日が読めない推定は nil
    init?(_ estimate: SyncedExpenditureEstimate) {
        guard let effectiveDay = CalendarDay(yearMonthDay: estimate.effectiveOn) else {
            return nil
        }
        self.init(
            id: estimate.id,
            effectiveDay: effectiveDay,
            expenditureKilocalories: estimate.expenditureKilocalories,
            estimatedAt: estimate.estimatedAt,
            initialSource: estimate.initialSource.map(InitialSource.init)
        )
    }
}

extension ExpenditureEstimate.InitialSource {
    init(_ source: SyncedExpenditureEstimate.InitialSource) {
        switch source {
        case .backCalculated: self = .backCalculated
        case .formula: self = .formula
        }
    }
}
