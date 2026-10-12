import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

/// 偽の同期サーバーは見守る要求につながない（404 を返す）ので、見守る要求はつないですぐ閉じる
@Suite("送り待ちを送って取りに行く段取り")
struct RecordSyncTests {
    @Suite("文章を送ったあと")
    struct AfterSendingText {
        @Suite("サーバーが5回めの取得で返事をするとき")
        struct RepliedAtFifthPull {
            let device: RecordSyncDevice

            init() throws {
                let clock = SteppingClock()
                device = try RecordSyncDevice(
                    clock: clock,
                    server: .passing(
                        .init(
                            records: [], startedOn: RecordSyncDevice.startedOn,
                            answerSentText: { _ in .reply("こんにちは。") }, sentTextAnswerPulls: 5),
                        clock: clock))
            }

            @Test(
                "送ってすぐと、見守る要求が閉じてすぐに取りに行き、そのあとは3秒おきに取りに行って、5回めで返事を受け取ること",
                .timeLimit(.minutes(1)))
            func pullsRightAwayThenEveryThreeSeconds() async throws {
                try await device.recordSync.sendText("こんにちは")
                await device.reflection.finishedSyncs.reaches(2)
                let pullTimesBeforeWaiting = device.server.pullTimes
                await device.advance(by: .seconds(3), untilFinishedSyncs: 3)
                await device.advance(by: .seconds(3), untilFinishedSyncs: 4)
                let repliesBeforeFifthPull = device.store.cache.aiUtterances.count
                await device.advance(by: .seconds(3), untilFinishedSyncs: 5)

                #expect(pullTimesBeforeWaiting == [.zero, .zero])
                #expect(
                    device.server.pullTimes == [
                        .zero, .zero, .seconds(3), .seconds(6), .seconds(9),
                    ])
                #expect(repliesBeforeFifthPull == 0)
                #expect(device.store.cache.aiUtterances.values.map(\.body) == ["こんにちは。"])
            }

            @Test("送り待ちを先に保存してから、キャッシュに保存すること")
            func savesPendingBeforeCache() async throws {
                try await device.recordSync.sendText("こんにちは")

                #expect(
                    device.store.saves.prefix(2) == [
                        .pending(added: 1, removed: 0), .cache(changes: 1, afterSequence: nil),
                    ])
            }
        }

        @Suite("サーバーが3回めの取得で食事と読み分け、その次の取得で推定を終えるとき")
        struct ClassifiedAsMealAtThirdPull {
            let device: RecordSyncDevice

            init() throws {
                let clock = SteppingClock()
                device = try RecordSyncDevice(
                    clock: clock,
                    server: .passing(
                        .init(
                            records: [], startedOn: RecordSyncDevice.startedOn,
                            estimatedDishes: { mealId in
                                [
                                    .dish(
                                        SyncedDish(
                                            id: UUID(), mealId: mealId, name: "親子丼",
                                            quantity: .init(
                                                value: 1, unit: "杯", source: .estimated),
                                            positionInMeal: 0, version: 1))
                                ]
                            },
                            answerSentText: { _ in .meal(replyAsConversation: "親子丼の話ですね。") },
                            sentTextAnswerPulls: 3),
                        clock: clock))
            }

            @Test(
                "読み分けが届くまで3秒おきに取りに行き、届いたら推定を終えるまで3秒おきに取りに行くこと",
                .timeLimit(.minutes(1)))
            func followsReplyThenEstimation() async throws {
                try await device.recordSync.sendText("昼は親子丼")
                await device.reflection.finishedSyncs.reaches(2)
                let mealsBeforeThirdPull = device.store.cache.meals.count
                await device.advance(by: .seconds(3), untilFinishedSyncs: 3)
                let statusesAfterThirdPull = Array(device.store.cache.estimationStatuses.values)
                await device.advance(by: .seconds(3), untilFinishedSyncs: 4)

                #expect(mealsBeforeThirdPull == 0)
                #expect(statusesAfterThirdPull == [.estimating])
                #expect(Array(device.store.cache.estimationStatuses.values) == [.estimated])
                #expect(device.store.cache.dishes.values.map(\.name) == ["親子丼"])
                #expect(device.server.pullTimes == [.zero, .zero, .seconds(3), .seconds(6)])
            }
        }
    }

    @Suite("同期が動いているあいだに、もう一度同期を呼んだとき")
    struct SyncWhileInFlight {
        let device: RecordSyncDevice

        init() throws {
            let clock = SteppingClock()
            device = try RecordSyncDevice(
                clock: clock,
                server: .holdingPulls(
                    .init(records: [], startedOn: RecordSyncDevice.startedOn), clock: clock))
        }

        @Test("動いている1回にまとめ、取りに行くのは1回であること", .timeLimit(.minutes(1)))
        func joinsInFlightSync() async throws {
            let recordSync = device.recordSync
            let first = Task { try await recordSync.sync() }
            await device.server.pullArrivals.reaches(1)
            let secondStarted = Tally()
            let second = Task {
                secondStarted.add()
                return try await recordSync.sync()
            }
            await secondStarted.reaches(1)
            // 2つめが段取りに入ってから、取得を通す。段取りの中を1往復して、2つめを先に入らせる
            _ = await recordSync.hasNotice(id: UUID())
            device.server.releasePulls()
            let results = [try await first.value, try await second.value]

            #expect(results.map { $0?.ending } == [.finished, .finished])
            #expect(device.server.pullTimes.count == 1)
            #expect(device.reflection.finishedSyncs.count == 1)
        }

        @Test("書き込みを送るための同期は、動いている1回が終わってから、もう1回取りに行くこと", .timeLimit(.minutes(1)))
        func syncsAgainAfterInFlightSync() async throws {
            let recordSync = device.recordSync
            let first = Task { try await recordSync.sync() }
            await device.server.pullArrivals.reaches(1)
            let secondStarted = Tally()
            let second = Task {
                secondStarted.add()
                await recordSync.followEstimationAfterSending()
            }
            await secondStarted.reaches(1)
            // 2つめが段取りに入ってから、取得を通す。段取りの中を1往復して、2つめを先に入らせる
            _ = await recordSync.hasNotice(id: UUID())
            device.server.releasePulls()
            _ = try await first.value
            await second.value

            #expect(device.server.pullTimes.count == 2)
            #expect(device.reflection.finishedSyncs.count == 2)
        }
    }

    @Suite("同期を終えて、次に知らせを出すかを決める時刻を待っているとき")
    struct WaitingForNoticeTime {
        let device: RecordSyncDevice

        init() async throws {
            let clock = SteppingClock()
            device = try RecordSyncDevice(
                clock: clock,
                server: .passing(
                    .init(records: [], startedOn: RecordSyncDevice.startedOn), clock: clock))
            // 見張りは、同期で次の時刻を決める
            _ = try await device.recordSync.sync()
            device.recordSync.startWaitingForNoticeTime()
            // 待つ側が来るまで待つ。時計は進めない
            await clock.advance(by: .zero)
            try #require(clock.sleeperCount == 1)
        }

        @Test("待つのをやめると、段取りの順番を待たずに、その場で待ちを取り消すこと", .timeLimit(.minutes(1)))
        func cancelsRightAway() {
            device.recordSync.stopWaitingForNoticeTime()

            #expect(device.clock.sleeperCount == 0)
        }
    }
}
