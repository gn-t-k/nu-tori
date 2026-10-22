public import NuToriAPI

/// サブスクリプションの状態の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct SubscriptionStatusSyncing: CacheApplying {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.subscriptionStatus

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    /// 最後に届いた状態を置く。届いていなければ何もしない。消えない
    public func apply(
        _ changes: [SyncChange], to cache: any SingleRecordCache<SubscriptionStatus>
    ) throws {
        if let status = current(from: changes) {
            try cache.write(status)
        }
    }

    public func erase(_ cache: any SingleRecordCache<SubscriptionStatus>) throws {
        try cache.clear()
    }

    /// 取りに行った変更のうち、最後に届いた読める状態。届いていなければ nil（キャッシュを変えない）。
    /// 最後の日が日付として読めない状態は読み飛ばす
    public func current(from changes: [SyncChange]) -> SubscriptionStatus? {
        var latest: SubscriptionStatus?
        for change in changes {
            if case .subscriptionStatus(let synced) = change,
                let status = SubscriptionStatus(synced)
            {
                latest = status
            }
        }
        return latest
    }
}

extension SubscriptionStatus {
    init?(_ synced: SyncedSubscriptionStatus) {
        switch synced {
        case .testUser:
            self = .testUser
        case .regular(let freeTrial, let subscription):
            let trial: FreeTrial
            switch freeTrial {
            case .available(let lastDay):
                guard let day = CalendarDay(yearMonthDay: lastDay) else { return nil }
                trial = .available(lastDay: day)
            case .usedByEarlierAccount:
                trial = .usedByEarlierAccount
            }
            self = .regular(freeTrial: trial, subscription: Subscription(subscription))
        }
    }
}

extension SubscriptionStatus.Subscription {
    init(_ synced: SyncedSubscriptionStatus.Subscription) {
        switch synced {
        case .none:
            self = .none
        case .subscribed(let plan, let periodEndsAt, let billingGrace):
            self = .subscribed(
                plan: SubscriptionStatus.Plan(plan), periodEndsAt: periodEndsAt,
                billingGrace: SubscriptionStatus.BillingGrace(billingGrace))
        }
    }
}

extension SubscriptionStatus.Plan {
    init(_ synced: SyncedSubscriptionStatus.Plan) {
        self =
            switch synced {
            case .monthly: .monthly
            case .yearly: .yearly
            }
    }
}

extension SubscriptionStatus.BillingGrace {
    init(_ synced: SyncedSubscriptionStatus.BillingGrace) {
        self =
            switch synced {
            case .none: .none
            case .granted(let endsAt): .granted(endsAt: endsAt)
            }
    }
}
