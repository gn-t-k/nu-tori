import Foundation

/// recordId は最初のサインインの ID の1つだけで、端末は使わない
struct SubscriptionStatusWireCoding: RecordKindWireCoding {
    let kind = Components.Schemas.RecordKindName.subscriptionStatus

    var writes: (any RecordKindWriteWireCoding)? { nil }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.SubscriptionStatusPayload.self).syncedStatus)
                .map { .subscriptionStatus($0) }
        case .deletion, .absence: nil
        }
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            guard case .subscriptionStatus(let status) = change else { return nil }
            return .value(
                id: SyncChange.SubscriptionStatusPayload.fakeRecordId,
                record: SyncChange.SubscriptionStatusPayload(status))
        }
    #endif
}

extension SyncChange {
    /// 型の値（`type`）で分かれる形を、欄を省略できる1つの形で読む。知らない値と、形に合わない組は nil にする。
    /// サーバーが値を足しても、古い版のアプリは前の状態のまま同期を続ける
    struct SubscriptionStatusPayload: Decodable {
        let type: String
        let freeTrial: FreeTrial?
        let subscription: Subscription?

        struct FreeTrial: Codable {
            let type: String
            let lastDay: String?
        }

        struct Subscription: Codable {
            let type: String
            let plan: String?
            let periodEndsAt: String?
            let billingGrace: BillingGrace?
        }

        struct BillingGrace: Codable {
            let type: String
            let endsAt: String?
        }

        var syncedStatus: SyncedSubscriptionStatus? {
            switch type {
            case "test_user": return .testUser
            case "regular":
                guard let freeTrial = freeTrial.flatMap(Self.freeTrial),
                    let subscription = subscription.flatMap(Self.subscription)
                else { return nil }
                return .regular(freeTrial: freeTrial, subscription: subscription)
            // swiftlint:disable:next no_default_in_switch - サーバーの名前は文字列で、知らない値が来る
            default: return nil
            }
        }

        private static func freeTrial(_ freeTrial: FreeTrial) -> SyncedSubscriptionStatus.FreeTrial?
        {
            switch (freeTrial.type, freeTrial.lastDay) {
            case ("available", .some(let lastDay)): .available(lastDay: lastDay)
            case ("used_by_earlier_account", _): .usedByEarlierAccount
            // swiftlint:disable:next no_default_in_switch - サーバーの名前は文字列で、知らない値が来る
            default: nil
            }
        }

        private static func subscription(_ subscription: Subscription)
            -> SyncedSubscriptionStatus.Subscription?
        {
            switch subscription.type {
            case "none": return SyncedSubscriptionStatus.Subscription.none
            case "subscribed":
                guard let plan = subscription.plan.flatMap(SyncedSubscriptionStatus.Plan.init),
                    let periodEndsAt = subscription.periodEndsAt.flatMap(Date.init(iso8601:)),
                    let billingGrace = subscription.billingGrace.flatMap(Self.billingGrace)
                else { return nil }
                return .subscribed(
                    plan: plan, periodEndsAt: periodEndsAt, billingGrace: billingGrace)
            // swiftlint:disable:next no_default_in_switch - サーバーの名前は文字列で、知らない値が来る
            default: return nil
            }
        }

        private static func billingGrace(_ billingGrace: BillingGrace)
            -> SyncedSubscriptionStatus.BillingGrace?
        {
            switch (billingGrace.type, billingGrace.endsAt.flatMap(Date.init(iso8601:))) {
            case ("none", _): SyncedSubscriptionStatus.BillingGrace.none
            case ("granted", .some(let endsAt)): .granted(endsAt: endsAt)
            // swiftlint:disable:next no_default_in_switch - サーバーの名前は文字列で、知らない値が来る
            default: nil
            }
        }
    }
}

extension Date {
    /// サーバーの ISO 8601 の時刻（`Date.toISOString()` の小数の秒つきの形と、小数の秒の無い形）を読む
    init?(iso8601 text: String) {
        if let date = try? Date(
            text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
        {
            self = date
        } else if let date = try? Date(text, strategy: .iso8601) {
            self = date
        } else {
            return nil
        }
    }

    /// サーバーと同じ、小数の秒つきの ISO 8601 の時刻
    var iso8601WithFractionalSeconds: String {
        formatted(.iso8601.year().month().day().time(includingFractionalSeconds: true))
    }
}

#if DEBUG
    extension SyncChange.SubscriptionStatusPayload: Encodable {
        /// 偽の同期サーバーが置く記録の ID。端末は読まないので、固定の値にする
        static let fakeRecordId = UUID(uuidString: "00000000-0000-4000-8000-00000000f175")!

        init(_ status: SyncedSubscriptionStatus) {
            switch status {
            case .testUser:
                self.init(type: "test_user", freeTrial: nil, subscription: nil)
            case .regular(let freeTrial, let subscription):
                self.init(
                    type: "regular", freeTrial: Self.freeTrialPayload(freeTrial),
                    subscription: Self.subscriptionPayload(subscription))
            }
        }

        private static func freeTrialPayload(_ freeTrial: SyncedSubscriptionStatus.FreeTrial)
            -> FreeTrial
        {
            switch freeTrial {
            case .available(let lastDay): FreeTrial(type: "available", lastDay: lastDay)
            case .usedByEarlierAccount: FreeTrial(type: "used_by_earlier_account", lastDay: nil)
            }
        }

        private static func subscriptionPayload(
            _ subscription: SyncedSubscriptionStatus.Subscription
        ) -> Subscription {
            switch subscription {
            case .none:
                return Subscription(
                    type: "none", plan: nil, periodEndsAt: nil, billingGrace: nil)
            case .subscribed(let plan, let periodEndsAt, let billingGrace):
                let grace =
                    switch billingGrace {
                    case .none: BillingGrace(type: "none", endsAt: nil)
                    case .granted(let endsAt):
                        BillingGrace(
                            type: "granted", endsAt: endsAt.iso8601WithFractionalSeconds)
                    }
                return Subscription(
                    type: "subscribed", plan: plan.rawValue,
                    periodEndsAt: periodEndsAt.iso8601WithFractionalSeconds, billingGrace: grace)
            }
        }
    }
#endif
