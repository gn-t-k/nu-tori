import Foundation

/// 週の見直しは消えないので、削除の印を持たない
struct WeeklyReviewWireCoding: RecordKindWireCoding {
    let kind = Components.Schemas.RecordKindName.weeklyReview

    var writes: (any RecordKindWriteWireCoding)? { nil }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.WeeklyReviewPayload.self).syncedWeeklyReview)
                .map { .weeklyReview($0) }
        case .deletion, .absence: nil
        }
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            guard case .weeklyReview(let review) = change else { return nil }
            return .value(id: review.id, record: SyncChange.WeeklyReviewPayload(review))
        }
    #endif
}

extension SyncChange {
    /// 読めない ID・タイムゾーンと、知らない理由と、見直しと見送りのどちらも付かない（両方付く）週は nil にする。
    /// 理由を落として読むと、見直せた週か見送った週かを取り違えるため
    struct WeeklyReviewPayload: Decodable {
        let id: String
        let effectiveOn: String
        let reviewedAt: Int
        let timeZone: String
        /// 見送った週だけに付く
        let deferral: Deferral?
        /// 見直せた週だけに付く
        let review: Review?

        struct Deferral: Decodable {
            let reason: String
            let goalId: String
        }

        struct Review: Decodable {
            let expenditureEstimateId: String
            let dailyGuideId: String
            let mainReason: String
        }

        var syncedWeeklyReview: SyncedWeeklyReview? {
            guard let id = UUID(uuidString: id), let timeZone = TimeZone(identifier: timeZone),
                let outcome
            else { return nil }
            return SyncedWeeklyReview(
                id: id,
                effectiveOn: effectiveOn,
                reviewedAt: Date(millisecondsSince1970: reviewedAt),
                timeZone: timeZone,
                outcome: outcome
            )
        }

        private var outcome: SyncedWeeklyReview.Outcome? {
            switch (review, deferral) {
            case (let review?, nil):
                guard let expenditureEstimateId = UUID(uuidString: review.expenditureEstimateId),
                    let dailyGuideId = UUID(uuidString: review.dailyGuideId),
                    let mainReason = SyncedWeeklyReview.MainReason(rawValue: review.mainReason)
                else { return nil }
                return .reviewed(
                    expenditureEstimateId: expenditureEstimateId, dailyGuideId: dailyGuideId,
                    mainReason: mainReason)
            case (nil, let deferral?):
                guard let reason = SyncedWeeklyReview.DeferralReason(rawValue: deferral.reason),
                    let goalId = UUID(uuidString: deferral.goalId)
                else { return nil }
                return .deferred(reason: reason, goalId: goalId)
            case (nil, nil), (.some, .some):
                return nil
            }
        }
    }
}

#if DEBUG
    extension SyncChange.WeeklyReviewPayload: Encodable {
        fileprivate init(_ review: SyncedWeeklyReview) {
            var deferral: Deferral?
            var reviewed: Review?
            switch review.outcome {
            case .reviewed(let expenditureEstimateId, let dailyGuideId, let mainReason):
                reviewed = .init(
                    expenditureEstimateId: expenditureEstimateId.canonicalString,
                    dailyGuideId: dailyGuideId.canonicalString, mainReason: mainReason.rawValue)
            case .deferred(let reason, let goalId):
                deferral = .init(reason: reason.rawValue, goalId: goalId.canonicalString)
            }
            self.init(
                id: review.id.canonicalString,
                effectiveOn: review.effectiveOn,
                reviewedAt: review.reviewedAt.millisecondsSince1970,
                timeZone: review.timeZone.identifier,
                deferral: deferral,
                review: reviewed
            )
        }
    }
    extension SyncChange.WeeklyReviewPayload.Deferral: Encodable {}
    extension SyncChange.WeeklyReviewPayload.Review: Encodable {}
#endif
