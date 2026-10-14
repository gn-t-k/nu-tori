public import Foundation
public import NuToriAPI

/// 1日の目安の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct DailyGuideSyncing: CacheApplying {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.dailyGuide

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    /// 届いた順に1日の目安を書く。目標と推定消費カロリーがまだ無い1日の目安も置く（届く順は約束しない）。1日の目安は消えない
    public func apply(_ changes: [SyncChange], to cache: any KeyedRecordCache<DailyGuide, UUID>)
        throws
    {
        for guide in current(from: changes) {
            try cache.upsert(guide)
        }
    }

    public func erase(_ cache: any KeyedRecordCache<DailyGuide, UUID>) throws {
        try cache.removeAll()
    }

    /// 取りに行った変更を、今の値の並び（届いた順）にする。目標より先に届いた1日の目安も返す。
    /// 当てる始まりの日が読めない1日の目安は読み飛ばす
    public func current(from changes: [SyncChange]) -> [DailyGuide] {
        changes.compactMap { change in
            guard case .dailyGuide(let synced) = change else { return nil }
            return DailyGuide(synced)
        }
    }
}

extension DailyGuide {
    /// 当てる始まりの日が読めない1日の目安は nil
    init?(_ guide: SyncedDailyGuide) {
        guard let effectiveDay = CalendarDay(yearMonthDay: guide.effectiveOn) else { return nil }
        self.init(
            id: guide.id,
            goalId: guide.goalId,
            expenditureEstimateId: guide.expenditureEstimateId,
            effectiveDay: effectiveDay,
            energyKilocalories: guide.energyKilocalories,
            proteinGrams: guide.proteinGrams,
            fatGrams: guide.fatGrams,
            carbohydrateGrams: guide.carbohydrateGrams,
            limitHits: guide.limitHits.map(LimitHit.init)
        )
    }
}

extension DailyGuide.LimitHit {
    init(_ limitHit: SyncedDailyGuide.LimitHit) {
        switch limitHit {
        case .weeklyChange: self = .weeklyChange
        case .requiredPace: self = .requiredPace
        case .minimumEnergy: self = .minimumEnergy
        }
    }
}
