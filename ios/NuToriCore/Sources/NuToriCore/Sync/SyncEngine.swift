public import Foundation
public import NuToriAPI

public actor SyncEngine {
    /// `readableKinds` は今読める種類の名前（登録簿の名前の集合）。前に読めた種類に無い名前があると、全部取り直す
    public init(
        store: any SyncBox & RecordCacheReading,
        client: NuToriAPIClient,
        accountId: String,
        device: SyncDevice,
        timeZone: @escaping @Sendable () -> TimeZone,
        now: @escaping @Sendable () -> Date,
        readableKinds: Set<RecordKindName>,
        errorReporting: any ErrorReportingSession,
        weightHealthExport: any WeightHealthExport,
        nutritionHealthExport: any NutritionHealthExport,
        mealPhotos: MealPhotos
    ) {
        self.store = store
        self.client = client
        self.accountId = accountId
        self.device = device
        self.timeZone = timeZone
        self.now = now
        self.readableKinds = readableKinds
        self.errorReporting = errorReporting
        self.weightHealthExport = weightHealthExport
        self.nutritionHealthExport = nutritionHealthExport
        self.mealPhotos = mealPhotos
    }

    @discardableResult
    public func save(_ write: WeightEntry.Write) async throws -> WeightRecord {
        switch write {
        case .create(let kilograms, let instant, let timeZone):
            let record = WeightRecord(
                id: UUID(),
                kilograms: kilograms,
                instant: instant,
                timeZone: timeZone,
                inputSource: .manual,
                version: 1
            )
            try await writingCache {
                try await store.apply(
                    WeightRecordSyncing().saving(
                        record, enqueuing: pendingWrite(.createWeightRecord(record))))
            }
            return record
        case .correct(let record):
            guard try await store.weightRecord(id: record.id) != nil else {
                throw UnknownRecordError(recordId: record.id)
            }
            try await writingCache {
                try await store.apply(
                    WeightRecordSyncing().saving(
                        record,
                        enqueuing: pendingWrite(.correctWeightRecord(record))
                    )
                )
            }
            return record
        }
    }

    /// 食事を記録する。食事の ID はここで振る。電波が無くても受け付け、送り待ちに並べる。
    /// `originals` は写真の ID ごとの元の写真で、アプリの中に置いてから、縮小版を裏で送り始める
    @discardableResult
    public func recordMeal(_ draft: MealDraft, originals: [UUID: Data]) async throws -> Meal {
        let meal = Meal(id: UUID(), draft: draft)
        // 写真を置けなかった食事を送ると、サーバーで写真を待ったまま残るので、写真を先に置く
        try await mealPhotos.keep(originals, of: meal)
        try await writingCache {
            try await store.apply(
                MealSyncing().recording(meal, enqueuing: pendingMealWrite(.create(meal))))
        }
        return meal
    }

    /// 食事を消す。電波が無くても、その場でキャッシュから消し、消す書き込みを送り待ちに並べ、アプリの中の写真を消す
    public func deleteMeal(id mealId: UUID) async throws {
        try await writingCache {
            try await store.apply(
                MealSyncing().deleting(
                    mealId: mealId, enqueuing: pendingMealWrite(.delete(mealId: mealId))))
        }
        await mealPhotos.discardPhotos(ofMeal: mealId)
        try await exportNutritionBestEffort()
    }

    /// 知らせを出す。電波が無くても受け付け、作る書き込みを送り待ちに並べる。
    /// ID と出した時刻は呼び出し側が決める（出すかの判断も呼び出し側）
    public func issueNotice(_ notice: Notice) async throws {
        try await writingCache {
            try await store.apply(
                NoticeSyncing().issuing(
                    notice, enqueuing: pendingNoticeWrite(.create(notice))))
        }
    }

    /// 知らせに答える。答えた時刻とタイムゾーンは今。電波が無くても受け付け、答える書き込みを送り待ちに並べる。
    /// すでに答えた知らせには何もしない
    public func respondToNotice(id noticeId: UUID) async throws {
        let notices = try await readingCache { try await store.notices() }
        guard let notice = notices.first(where: { $0.id == noticeId }) else {
            throw UnknownRecordError(recordId: noticeId)
        }
        guard notice.response == nil else { return }
        let response = Notice.Response(respondedAt: now(), timeZone: timeZone())
        try await writingCache {
            try await store.apply(
                NoticeSyncing().responding(
                    to: notice, with: response,
                    enqueuing: pendingNoticeWrite(
                        .respond(noticeId: noticeId, response: response))))
        }
    }

    /// キャッシュの体重記録と知らせから、体重の知らせに答えるか・今日の知らせを出すかを決め、書き込みを送り待ちに並べる。
    /// 初回の取得を終えるまでは、記録がそろっていないので何もしない。並べたら true。
    /// 読めなかった・書けなかったら、報告して false
    @discardableResult
    public func issueOrRespondToMissedWeightRecordNotices() async -> Bool {
        await decidingMissedWeightRecordNotices { inputs in
            let responded = try await enqueueMissedWeightRecordNoticeResponses(with: inputs)
            let noticeToIssue = MissedWeightRecordNoticeDecision.noticeToIssue(
                usualWeighingTime: inputs.usualWeighingTime,
                now: now(),
                timeZone: timeZone(),
                weightRecords: inputs.weightRecords,
                notices: inputs.notices
            )
            if let noticeToIssue {
                try await issueNotice(noticeToIssue)
            }
            return responded || noticeToIssue != nil
        }
    }

    /// 体重の知らせに答えるかだけを決め、答える書き込みを送り待ちに並べる。今日の知らせは出さない。
    /// 初回の取得を終えるまでは何もしない。並べたら true。読めなかった・書けなかったら、報告して false
    @discardableResult
    public func respondToMissedWeightRecordNotices() async -> Bool {
        await decidingMissedWeightRecordNotices { inputs in
            try await enqueueMissedWeightRecordNoticeResponses(with: inputs)
        }
    }

    /// 利用状況を送るかの切り替え。電波が無くても受け付け、送り待ちに並べる
    public func setSendsUsageData(_ sendsUsageData: Bool) async throws {
        let settings = AccountSettings(
            id: AccountSettings.id(forAccountId: accountId),
            sendsUsageData: sendsUsageData
        )
        try await writingCache {
            try await store.apply(
                AccountSettingsSyncKind().saving(
                    settings, enqueuing: pendingWrite(.updateAccountSettings(settings))))
        }
    }

    public func usageDataSetting() async throws -> UsageDataSetting {
        UsageDataSetting(
            accountSettings: try await store.accountSettings(),
            hasCompletedInitialPull: try await store.syncState()?.hasCompletedInitialPull ?? false
        )
    }

    public func sync() async throws -> SyncResult {
        var rejectedWrites: [RejectedWrite] = []
        let stoppedBy: SyncResult.StopReason?
        if let pushStop = try await pushPendingWrites(collectingRejectionsIn: &rejectedWrites) {
            stoppedBy = pushStop
        } else {
            stoppedBy = try await pullChanges()
        }
        return SyncResult(
            rejectedWrites: rejectedWrites,
            ending: stoppedBy.map { .stopped($0) } ?? .finished
        )
    }

    public struct UnknownRecordError: Error, Equatable {
        public let recordId: UUID

        public init(recordId: UUID) {
            self.recordId = recordId
        }
    }

    private let store: any SyncBox & RecordCacheReading
    private let client: NuToriAPIClient
    private let accountId: String
    private let device: SyncDevice
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date
    private let readableKinds: Set<RecordKindName>
    private let errorReporting: any ErrorReportingSession
    private let weightHealthExport: any WeightHealthExport
    private let nutritionHealthExport: any NutritionHealthExport
    private let mealPhotos: MealPhotos

    private func pendingWrite(_ operation: PendingWrite.Operation) -> PendingWrite {
        PendingWrite(writeId: UUID(), enqueuedAt: now(), operation: operation)
    }

    private func pendingMealWrite(_ write: PendingMealWrite.Write) -> PendingMealWrite {
        PendingMealWrite(writeId: UUID(), enqueuedAt: now(), write: write)
    }

    private func pendingNoticeWrite(_ write: PendingNoticeWrite.Write) -> PendingNoticeWrite {
        PendingNoticeWrite(writeId: UUID(), enqueuedAt: now(), write: write)
    }

    private func pushPendingWrites(collectingRejectionsIn rejectedWrites: inout [RejectedWrite])
        async throws -> SyncResult.StopReason?
    {
        let maxWritesPerRequest = 500
        let pending = try await store.pendingEntries()
        for batchStart in stride(from: 0, to: pending.count, by: maxWritesPerRequest) {
            let batchEnd = min(batchStart + maxWritesPerRequest, pending.count)
            let batch = Array(pending[batchStart..<batchEnd])
            let writes = try batch.map(syncWrite)
            let clientState = await clientState(pendingWrites: pending[batchStart...])
            let result: NuToriAPIClient.PushSyncWritesResult
            do {
                result = try await client.pushSyncWrites(
                    writes,
                    isFinalBatch: batchEnd == pending.count,
                    clientState: clientState
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch  where error.isAppBuildUnsupported {
                return .appBuildUnsupported
            } catch {
                if let failure = HandledFailure.reported(error, as: .sync) {
                    await errorReporting.report(failure)
                }
                return .unavailable
            }
            switch result {
            case .pushed(let results):
                try await resolve(batch, with: results, rejectedWrites: &rejectedWrites)
            case .badRequest:
                return .badRequest
            case .sessionExpired:
                return .sessionExpired
            case .rateLimited:
                return .rateLimited
            }
        }
        return nil
    }

    private func kind(named name: RecordKindName) throws -> any SyncedRecordKind {
        guard let kind = store.recordKinds.first(where: { $0.name == name }) else {
            throw UnknownRecordKindError.notRegistered(name)
        }
        return kind
    }

    /// 送り待ちの種類の、書き込みの扱い。サーバーだけが書く種類の送り待ちは、送れない
    private func writes(for entry: PendingEntry) throws -> any RecordKindWrites {
        guard let writes = try kind(named: entry.kind).writes else {
            throw UnknownRecordKindError.serverOnly(entry.kind)
        }
        return writes
    }

    /// 種類が、送る書き込みにする
    private func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        try writes(for: entry).syncWrite(for: entry)
    }

    /// 結果を、受け付けた・受け付けなかったの2つに畳んで読む。細かい結果はサーバーの控えと観測にだけ使う。
    /// 受け付けなかったら送り待ちから外し、添えられたサーバーの今の値を、取りに行った変更と同じ道で当てる
    private func resolve(
        _ batch: [PendingEntry],
        with results: [SyncWriteResult],
        rejectedWrites: inout [RejectedWrite]
    ) async throws {
        let resultsByWriteId = Dictionary(
            results.map { ($0.writeId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var resolvedWriteIds: [UUID] = []
        var currentChanges: [RecordKindName: [SyncChange]] = [:]
        for entry in batch {
            guard let result = resultsByWriteId[entry.writeId] else {
                continue
            }
            resolvedWriteIds.append(entry.writeId)
            guard case .rejected(let reason) = result.outcome else {
                continue
            }
            let rejection = try writes(for: entry).rejection(
                of: entry, reason: reason, current: result.current)
            if let rejected = rejection.rejectedWrite {
                rejectedWrites.append(rejected)
            }
            switch result.current {
            case .value(let change), .deleted(let change):
                currentChanges[entry.kind, default: []].append(change)
            case .absent:
                currentChanges[entry.kind, default: []] += rejection.removingChanges
            case nil:
                break
            }
        }
        try await writingCache {
            try await store.apply(
                SyncBoxResult(
                    resolvedWriteIds: resolvedWriteIds,
                    kindChanges: currentChanges.filter { !$0.value.isEmpty }
                        .sorted { $0.key < $1.key }
                        .map { KindChanges(kind: $0.key, changes: $0.value) }
                ))
        }
        await discardPhotos(ofDeletedMealsIn: currentChanges[MealSyncing.kindName] ?? [])
    }

    /// 削除の印が届いた食事と、受け付けられずにキャッシュから外した食事の写真は、ほかの端末で消したときも残らないよう、アプリの中から消す
    private func discardPhotos(ofDeletedMealsIn changes: [SyncChange]) async {
        for mealId in MealSyncing().current(from: changes).removedMealIds {
            await mealPhotos.discardPhotos(ofMeal: mealId)
        }
    }

    private func pullChanges() async throws -> SyncResult.StopReason? {
        var state = try await syncStateReadingCurrentKinds()
        while true {
            let clientState = await clientState(
                pendingWrites: try await store.pendingEntries()[...])
            let result: NuToriAPIClient.PullSyncChangesResult
            do {
                result = try await client.pullSyncChanges(
                    afterSequence: state.afterSequence,
                    clientState: clientState
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch  where error.isAppBuildUnsupported {
                return .appBuildUnsupported
            } catch {
                if let failure = HandledFailure.reported(error, as: .sync) {
                    await errorReporting.report(failure)
                }
                return .unavailable
            }
            switch result {
            case .pulled(let page):
                let kinds = store.recordKinds
                // 登録簿に無い種類の変更は読み飛ばす。名前がサーバーとそろっているかは、テストで見張る
                let ownedChanges = kinds.map { kind in
                    KindChanges(kind: kind.name, changes: page.changes.filter { kind.owns($0) })
                }.filter { !$0.changes.isEmpty }
                // ヘルスケアへの書き直しは、届いた体重記録に行う
                let revised = try await revisedManualRecords(
                    in: WeightRecordSyncing().current(from: page.changes).records)
                state = SyncState(
                    afterSequence: page.nextAfterSequence,
                    hasCompletedInitialPull: state.hasCompletedInitialPull || !page.hasMore,
                    readableKinds: readableKinds,
                    startedOn: page.startedOn
                )
                try await writingCache {
                    try await store.apply(
                        SyncBoxResult(kindChanges: ownedChanges, syncState: state))
                }
                await discardPhotos(ofDeletedMealsIn: page.changes)
                try await exportRevisedRecords(revised)
                if !page.hasMore {
                    // 頁の途中では、料理と材料がそろっていないことがあるので、取り切ってから書く
                    try await exportNutritionBestEffort()
                    return nil
                }
            case .badRequest:
                return .badRequest
            case .sessionExpired:
                return .sessionExpired
            case .rateLimited:
                return .rateLimited
            }
        }
    }

    private func syncStateReadingCurrentKinds() async throws -> SyncState {
        guard let saved = try await store.syncState() else {
            return SyncState(
                afterSequence: 0,
                hasCompletedInitialPull: false,
                readableKinds: readableKinds,
                startedOn: nil
            )
        }
        if readableKinds.isSubset(of: saved.readableKinds) {
            return saved
        }
        // 途中で終わっても、次は戻した通し番号の続きから取れるよう、すぐ保存する
        let restarted = SyncState(
            afterSequence: 0,
            hasCompletedInitialPull: saved.hasCompletedInitialPull,
            readableKinds: readableKinds,
            startedOn: saved.startedOn
        )
        try await writingCache {
            try await store.apply(SyncBoxResult(syncState: restarted))
        }
        return restarted
    }

    /// 体重の知らせを出すか・答えるかを決める材料
    private struct MissedWeightRecordNoticeInputs {
        let weightRecords: [WeightRecord]
        let notices: [Notice]
        let usualWeighingTime: UsualWeighingTime?
    }

    /// 初回の取得を終えていれば、材料を読んで決める。読めなかった失敗は readingCache が、書けなかった失敗は writingCache が報告しているので、ここでは重ねて送らない
    private func decidingMissedWeightRecordNotices(
        _ decide: (MissedWeightRecordNoticeInputs) async throws -> Bool
    ) async -> Bool {
        do {
            let inputs = try await readingCache { () -> MissedWeightRecordNoticeInputs? in
                guard try await store.syncState()?.hasCompletedInitialPull ?? false else {
                    return nil
                }
                return MissedWeightRecordNoticeInputs(
                    weightRecords: try await store.weightRecords(),
                    notices: try await store.notices(),
                    usualWeighingTime: try await store.usualWeighingTime()
                )
            }
            guard let inputs else { return false }
            return try await decide(inputs)
        } catch {
            return false
        }
    }

    private func enqueueMissedWeightRecordNoticeResponses(
        with inputs: MissedWeightRecordNoticeInputs
    )
        async throws -> Bool
    {
        let idsToRespond = MissedWeightRecordNoticeDecision.noticeIdsToRespond(
            notices: inputs.notices, weightRecords: inputs.weightRecords)
        for noticeId in idsToRespond {
            try await respondToNotice(id: noticeId)
        }
        return !idsToRespond.isEmpty
    }

    private func readingCache<T: Sendable>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let failure = HandledFailure.reported(error, as: .cacheRead) {
                await errorReporting.report(failure)
            }
            throw error
        }
    }

    private func writingCache<T: Sendable>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let failure = HandledFailure.reported(error, as: .cacheSave) {
                await errorReporting.report(failure)
            }
            throw error
        }
    }

    private func revisedManualRecords(in incoming: [WeightRecord]) async throws -> [WeightRecord] {
        var revised: [WeightRecord] = []
        for record in incoming {
            switch record.inputSource {
            case .imported:
                continue
            case .manual:
                guard let cached = try await store.weightRecord(id: record.id),
                    record.version > cached.version
                else { continue }
                revised.append(record)
            }
        }
        return revised
    }

    /// 書き直しに失敗しても、届いた記録はキャッシュに残す。次に版が上がったときに書き直す
    private func exportRevisedRecords(_ records: [WeightRecord]) async throws {
        for record in records {
            do {
                try await weightHealthExport.exportWeightRecord(record)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }
    }

    /// 書き込みの許可が無いなどで書けなくても、同期と食事を消すことは止めない。書けなかった料理は、次の同期で改めて試す
    private func exportNutritionBestEffort() async throws {
        do {
            try await nutritionHealthExport.exportNutrition()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return
        }
    }

    private func clientState(pendingWrites: ArraySlice<PendingEntry>) async -> SyncClientState {
        let pendingPhotoCount = await mealPhotos.pendingUploadCount()
        let currentTime = now()
        return SyncClientState(
            deviceId: device.deviceId,
            timeZone: timeZone(),
            appVersion: device.appVersion,
            osVersion: device.osVersion,
            pendingWriteCount: pendingWrites.count,
            oldestPendingWriteAge: pendingWrites.map(\.enqueuedAt).min().map {
                .seconds(max(0, currentTime.timeIntervalSince($0)))
            },
            pendingPhotoCount: pendingPhotoCount
        )
    }
}
