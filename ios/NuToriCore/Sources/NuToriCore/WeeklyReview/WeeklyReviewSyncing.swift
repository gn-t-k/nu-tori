public import Foundation
public import NuToriAPI

/// 週の見直しの同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct WeeklyReviewSyncing: CacheApplying {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.weeklyReview

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    /// 届いた順に見直しを書く。指す記録がまだキャッシュに無くても書く。見直しは消えない
    public func apply(
        _ changes: [SyncChange], to cache: any KeyedRecordCache<WeeklyReview, UUID>
    ) throws {
        for review in current(from: changes) {
            try cache.upsert(review)
        }
    }

    public func erase(_ cache: any KeyedRecordCache<WeeklyReview, UUID>) throws {
        try cache.removeAll()
    }

    /// 取りに行った変更を、今の値の並び（届いた順）にする。当てる月曜が読めない見直しは読み飛ばす
    public func current(from changes: [SyncChange]) -> [WeeklyReview] {
        changes.compactMap { change in
            guard case .weeklyReview(let synced) = change else { return nil }
            return WeeklyReview(synced)
        }
    }
}

extension WeeklyReview {
    /// 当てる月曜が読めない見直しは nil
    init?(_ review: SyncedWeeklyReview) {
        guard let effectiveDay = CalendarDay(yearMonthDay: review.effectiveOn) else { return nil }
        self.init(
            id: review.id,
            effectiveDay: effectiveDay,
            reviewedAt: review.reviewedAt,
            timeZone: review.timeZone,
            outcome: Outcome(review.outcome)
        )
    }
}

extension WeeklyReview.Outcome {
    init(_ outcome: SyncedWeeklyReview.Outcome) {
        switch outcome {
        case .reviewed(let expenditureEstimateId, let dailyGuideId, let mainReason):
            self = .reviewed(
                expenditureEstimateId: expenditureEstimateId, dailyGuideId: dailyGuideId,
                mainReason: WeeklyReview.MainReason(mainReason))
        case .deferred(let reason, let goalId):
            self = .deferred(reason: WeeklyReview.DeferralReason(reason), goalId: goalId)
        }
    }
}

extension WeeklyReview.MainReason {
    init(_ reason: SyncedWeeklyReview.MainReason) {
        switch reason {
        case .expenditureChange: self = .expenditureChange
        case .balanceChange: self = .balanceChange
        }
    }
}

extension WeeklyReview.DeferralReason {
    init(_ reason: SyncedWeeklyReview.DeferralReason) {
        switch reason {
        case .withinFirstWeek: self = .withinFirstWeek
        case .noWeight: self = .noWeight
        case .fewMealRecords: self = .fewMealRecords
        }
    }
}
