public import Foundation

/// 目標を立てる知らせの番。知らせを出すかと答えるかを、キャッシュの目標と知らせから決め、書き込みを送り待ちに積む。
/// 出すことと答えることは、呼んだ順に1つずつ扱う。並べて扱うと、同じ知らせの書き込みを二重に積みうるため
public actor GoalSetupNoticeKeeper {
    public init(
        cache: any SyncBox & RecordCacheReading,
        timeZone: @escaping @Sendable () -> TimeZone,
        now: @escaping @Sendable () -> Date,
        errorReporting: any ErrorReportingSession
    ) {
        self.cache = cache
        self.timeZone = timeZone
        self.now = now
        self.errorReporting = errorReporting
    }

    /// 目標を立てる知らせの ID。種類だけから決まり、1アカウントに1つ。2台目の端末も同じ ID で作る
    public static let noticeId = Notice.id(of: .goalSetup)

    /// 取りに行き終えたあとに呼ぶ。初回の取得を終えていて、キャッシュに目標の記録も目標を立てる知らせも無ければ、知らせを出す。
    /// 取りに行く前に決めると、ほかの端末で立てた目標が届く前に出してしまう。
    /// 知らせの書き込みを送り待ちに積んだかを返す。キャッシュを読めなければ、報告して出さない
    @discardableResult
    public func issueIfNoGoal() async -> Bool {
        await inOrder { await $0.issue() }
    }

    /// 「あとで」を押したときと、目標が決まったときに呼ぶ。キャッシュの目標を立てる知らせが答えていなければ、答える。
    /// 早いほうの1回だけが答えを積み、あとの呼び出しと、知らせが無いときは積まない。
    /// 答える書き込みを送り待ちに積んだかを返す
    @discardableResult
    public func respondIfUnanswered() async -> Bool {
        await inOrder { await $0.respond() }
    }

    private let cache: any SyncBox & RecordCacheReading
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date
    private let errorReporting: any ErrorReportingSession
    /// 呼んだ順に並べた仕事の、いちばん後ろ
    private var lastInOrder: Task<Void, Never>?

    private func inOrder(
        _ work: @escaping @Sendable (GoalSetupNoticeKeeper) async -> Bool
    ) async -> Bool {
        let previous = lastInOrder
        let task = Task {
            await previous?.value
            return await work(self)
        }
        lastInOrder = Task { _ = await task.value }
        return await task.value
    }

    private func issue() async -> Bool {
        do {
            guard try await cache.syncState()?.hasCompletedInitialPull ?? false,
                try await cache.goals().isEmpty,
                !(try await cache.notices().contains { $0.id == Self.noticeId })
            else { return false }
        } catch {
            await errorReporting.report(error, as: .cacheRead)
            return false
        }
        let now = now()
        let notice = Notice(
            id: Self.noticeId, kind: .goalSetup, issuedAt: now, timeZone: timeZone(),
            response: nil)
        do {
            try await cache.apply(
                NoticeSyncing().issuing(
                    notice, enqueuing: Pending(enqueuedAt: now, write: .create(notice))))
            return true
        } catch {
            await errorReporting.report(error, as: .cacheSave)
            return false
        }
    }

    private func respond() async -> Bool {
        let unanswered: Notice?
        do {
            unanswered = try await cache.notices().first {
                $0.id == Self.noticeId && $0.response == nil
            }
        } catch {
            await errorReporting.report(error, as: .cacheRead)
            return false
        }
        guard let unanswered else { return false }
        let now = now()
        let response = Notice.Response(respondedAt: now, timeZone: timeZone())
        do {
            try await cache.apply(
                NoticeSyncing().responding(
                    to: unanswered, with: response,
                    enqueuing: Pending(
                        enqueuedAt: now,
                        write: .respond(noticeId: unanswered.id, response: response))))
            return true
        } catch {
            await errorReporting.report(error, as: .cacheSave)
            return false
        }
    }
}
