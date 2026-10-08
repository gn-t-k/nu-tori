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
                        record, enqueuing: pending(.createWeightRecord(record))))
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
                        enqueuing: pending(.correctWeightRecord(record))
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
                MealSyncing().recording(meal, enqueuing: pending(.create(meal))))
        }
        return meal
    }

    /// 食事の撮った時刻を直す。時差・送った時刻・入口は変えない。電波が無くても、その場でキャッシュに当て、直す書き込みを送り待ちに並べる。
    /// 今と同じ時刻なら何もしない。キャッシュに無い食事は `UnknownRecordError`
    public func correctMealTime(mealId: UUID, eatenAt: Date) async throws {
        guard let meal = try await store.meals().first(where: { $0.id == mealId }) else {
            throw UnknownRecordError(recordId: mealId)
        }
        guard meal.eatenAt != eatenAt else { return }
        try await writingCache {
            try await store.apply(
                MealSyncing().correctingEatenAt(
                    of: meal, to: eatenAt,
                    enqueuing: pending(.update(mealId: mealId, eatenAt: eatenAt))))
        }
    }

    /// 食事を消す。電波が無くても、その場でキャッシュから消し、消す書き込みを送り待ちに並べ、アプリの中の写真を消す
    public func deleteMeal(id mealId: UUID) async throws {
        try await writingCache {
            try await store.apply(
                MealSyncing().deleting(
                    mealId: mealId, enqueuing: pending(.delete(mealId: mealId))))
        }
        await mealPhotos.discardPhotos(ofMeal: mealId)
        try await exportNutritionBestEffort()
    }

    /// 食事に料理を足す。名前だけで作り、量と材料はサーバーの推定し直しで入る。電波が無くても受け付け、送り待ちに並べる。
    /// 料理の ID は UUID の版 4、並び順はキャッシュのその食事の料理の最後の次。前後の空白を除いた名前で足し、空なら足さずに nil。
    /// キャッシュに無い食事は `UnknownRecordError`
    @discardableResult
    public func addDish(named typedName: String, toMeal mealId: UUID) async throws -> Dish? {
        guard try await store.meals().contains(where: { $0.id == mealId }) else {
            throw UnknownRecordError(recordId: mealId)
        }
        guard let name = Dish.acceptedName(typed: typedName) else { return nil }
        let lastPosition = try await store.dishes().filter { $0.mealId == mealId }
            .map(\.positionInMeal).max()
        let newDish = NewDish(
            id: UUID(), mealId: mealId, name: name,
            positionInMeal: lastPosition.map { $0 + 1 } ?? 0)
        let dish = Dish(
            id: newDish.id, mealId: mealId, name: name, quantity: nil,
            positionInMeal: newDish.positionInMeal, version: 1)
        try await writingCache {
            try await store.apply(DishSyncing().adding(dish, enqueuing: pending(.create(newDish))))
        }
        return dish
    }

    /// 料理の名前を直す。直したら、サーバーが推定し直しを始める。返すのは、キャッシュの今の料理。
    /// 前後の空白を除いて空の名前と、今と同じ名前は送らず、前の料理をそのまま返す（画面は前の名前に戻す）
    @discardableResult
    public func renameDish(id dishId: UUID, to typedName: String) async throws -> Dish {
        let dish = try await cachedDish(id: dishId)
        guard let edit = DishEdit.renaming(dish, to: typedName) else { return dish }
        try await apply(edit)
        return edit.dish
    }

    /// 料理の量を直す。その料理の今の材料の量を同じ割合で変え、比例させた材料の量を載せた書き込み1つで送る。
    /// 量の無い料理、受け付ける範囲の外の量、今と同じ量は送らず、前の料理をそのまま返す
    @discardableResult
    public func correctDishQuantity(id dishId: UUID, to value: Double) async throws -> Dish {
        let dish = try await cachedDish(id: dishId)
        let ingredients = try await store.ingredients()
        guard let edit = DishEdit.correctingQuantity(of: dish, ingredients: ingredients, to: value)
        else {
            return dish
        }
        try await apply(edit)
        return edit.dish
    }

    /// 材料の量を直す。料理の量は変えない。受け付ける範囲の外の量と今と同じ量は送らず、前の材料をそのまま返す。
    /// キャッシュに無い材料は `UnknownRecordError`
    @discardableResult
    public func correctIngredientQuantity(id ingredientId: UUID, to quantity: Double) async throws
        -> Ingredient
    {
        guard
            let ingredient = try await store.ingredients().first(where: { $0.id == ingredientId })
        else {
            throw UnknownRecordError(recordId: ingredientId)
        }
        guard
            let result = try IngredientSyncing().correcting(
                ingredient, to: quantity,
                enqueuing: pending(.update(ingredientId: ingredientId, quantity: quantity)))
        else {
            return ingredient
        }
        try await writingCache { try await store.apply(result) }
        return try await store.ingredients().first(where: { $0.id == ingredientId }) ?? ingredient
    }

    /// 料理を消す。電波が無くても、その場でキャッシュから料理と材料と料理ごとの推定の状態を消し、消す書き込みを送り待ちに並べ、
    /// ヘルスケアからも消しに行く。最後の1品かは画面が `MealEditOffer` で先に決め、最後の1品なら `deleteMeal` を呼ぶ
    public func deleteDish(id dishId: UUID) async throws {
        let ingredientIds = try await store.ingredients().filter { $0.dishId == dishId }.map(\.id)
        try await writingCache {
            try await store.apply(
                DishSyncing().deleting(
                    dishId: dishId, ingredientIds: ingredientIds,
                    enqueuing: pending(.delete(dishId: dishId))))
        }
        try await exportNutritionBestEffort()
    }

    /// 送り待ちに料理を足す・名前を直す書き込みがある料理。食事のカード（`MealCard`）に渡し、まだ送れていない料理として見せる
    public func unsentDishIds() async throws -> Set<UUID> {
        DishSyncing.unsentDishIds(in: try await store.pendingEntries())
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
                    settings, enqueuing: pending(.updateAccountSettings(settings))))
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
        var awaitingPullWriteIds: [UUID] = []
        let stoppedBy: SyncResult.StopReason?
        if let pushStop = try await pushPendingWrites(
            collectingRejectionsIn: &rejectedWrites, awaitingPullIn: &awaitingPullWriteIds)
        {
            stoppedBy = pushStop
        } else {
            stoppedBy = try await pullChanges()
            if stoppedBy == nil, !awaitingPullWriteIds.isEmpty {
                try await writingCache {
                    try await store.apply(SyncBoxResult(resolvedWriteIds: awaitingPullWriteIds))
                }
            }
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

    private func cachedDish(id dishId: UUID) async throws -> Dish {
        guard let dish = try await store.dishes().first(where: { $0.id == dishId }) else {
            throw UnknownRecordError(recordId: dishId)
        }
        return dish
    }

    /// 直した料理と比例の材料を、送り待ちを先に保存してからキャッシュに当てる
    private func apply(_ edit: DishEdit) async throws {
        try await writingCache {
            try await store.apply(
                DishSyncing().correcting(edit, enqueuing: pending(edit.write)))
        }
    }

    /// 今の時刻で送り待ちに並べる書き込み
    private func pending<Write>(_ write: Write) -> Pending<Write> {
        Pending(enqueuedAt: now(), write: write)
    }

    /// `awaitingPullWriteIds` には、受け付けたが、変更を取り切るまで送り待ちに残す書き込みを集める（`resolve`）
    private func pushPendingWrites(
        collectingRejectionsIn rejectedWrites: inout [RejectedWrite],
        awaitingPullIn awaitingPullWriteIds: inout [UUID]
    ) async throws -> SyncResult.StopReason? {
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
                await errorReporting.report(error, as: .sync)
                return .unavailable
            }
            switch result {
            case .pushed(let results):
                try await resolve(
                    batch, with: results, rejectedWrites: &rejectedWrites,
                    awaitingPullWriteIds: &awaitingPullWriteIds)
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
    /// 受け付けなかったら送り待ちから外し、添えられたサーバーの今の値を、取りに行った変更と同じ道で当てる。
    /// 受け付けた料理を足す・名前を直す書き込みは、料理ごとの推定の状態が届くまで料理をまだ送れていないとして見せるため、
    /// 変更を取り切るまで送り待ちに残す（取りに行けなければ次の同期で送り直し、帳簿は同じ書き込みの ID に同じ結果を返す）
    private func resolve(
        _ batch: [PendingEntry],
        with results: [SyncWriteResult],
        rejectedWrites: inout [RejectedWrite],
        awaitingPullWriteIds: inout [UUID]
    ) async throws {
        let resultsByWriteId = Dictionary(
            results.map { ($0.writeId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var resolvedWriteIds: [UUID] = []
        var currentChanges: [RecordKindName: [SyncChange]] = [:]
        // 行に出す名前と時刻は、サーバーの今の値を当てる前のキャッシュから読む。受け付けなかった書き込みがあるときだけ読む
        let shown =
            results.contains { if case .rejected = $0.outcome { true } else { false } }
            ? ShownRecords(
                meals: try await store.meals(), dishes: try await store.dishes(),
                ingredients: try await store.ingredients())
            : ShownRecords.none
        for entry in batch {
            guard let result = resultsByWriteId[entry.writeId] else {
                continue
            }
            guard case .rejected(let reason) = result.outcome else {
                if DishSyncing.unsentDishIds(in: [entry]).isEmpty {
                    resolvedWriteIds.append(entry.writeId)
                } else {
                    awaitingPullWriteIds.append(entry.writeId)
                }
                continue
            }
            resolvedWriteIds.append(entry.writeId)
            let rejection = try writes(for: entry).rejection(
                of: entry, reason: reason, current: result.current, shown: shown)
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
                await errorReporting.report(error, as: .sync)
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

    private func writingCache<T: Sendable>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            await errorReporting.report(error, as: .cacheSave)
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
