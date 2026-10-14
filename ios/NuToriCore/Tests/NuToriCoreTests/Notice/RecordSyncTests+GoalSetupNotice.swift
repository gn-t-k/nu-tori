import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension RecordSyncTests {
    @Suite("目標を立てる知らせ")
    struct GoalSetupNotice {
        static let noticeId = GoalSetupNoticeKeeper.noticeId

        static func device(
            records: [SyncChange],
            stateBeforeUpdate: (afterSequence: Int, readableKinds: Set<RecordKindName>)? = nil
        ) throws -> RecordSyncDevice {
            let clock = SteppingClock()
            return try RecordSyncDevice(
                clock: clock,
                server: .passing(
                    .init(records: records, startedOn: RecordSyncDevice.startedOn), clock: clock),
                goals: [], stateBeforeUpdate: stateBeforeUpdate)
        }

        /// 目標・1日の目安・推定消費カロリーを読めなかった、前の版の読める種類
        static var readableKindsBeforeUpdate: Set<RecordKindName> {
            RecordKindRegistry<RecordCacheMock>.ok().names
                .subtracting([.goal, .dailyGuide, .expenditureEstimate])
        }

        @Suite("サーバーに目標が無いまま、取りに行き終えたとき")
        struct NoGoalOnServer {
            let device: RecordSyncDevice

            init() throws {
                device = try GoalSetupNotice.device(records: [])
            }

            @Test("答えていない目標を立てる知らせを1つ作ること", .timeLimit(.minutes(1)))
            func issuesNotice() async throws {
                _ = try await device.recordSync.sync()

                #expect(device.store.cache.notices.values.map(\.kind) == [.goalSetup])
                #expect(device.store.cache.notices[GoalSetupNotice.noticeId]?.response == nil)
            }

            @Test("作る書き込みを、もう1回の同期ですぐ裏で送り、送り待ちに残さないこと", .timeLimit(.minutes(1)))
            func sendsCreateRightAway() async throws {
                _ = try await device.recordSync.sync()
                await device.reflection.finishedSyncs.reaches(2)

                #expect(device.store.entries.isEmpty)
                #expect(device.server.pullTimes.count == 2)
            }

            @Test("そのあと何度取りに行っても、知らせが1つのままで、送るための同期を足さないこと", .timeLimit(.minutes(1)))
            func keepsSingleNotice() async throws {
                _ = try await device.recordSync.sync()
                await device.reflection.finishedSyncs.reaches(2)
                _ = try await device.recordSync.sync()
                _ = try await device.recordSync.sync()

                #expect(device.store.entries.isEmpty)
                #expect(Array(device.store.cache.notices.keys) == [GoalSetupNotice.noticeId])
                #expect(device.server.pullTimes.count == 4)
            }

            @Test("目標が決まると、答えた形にして、答える書き込みを裏で送ること", .timeLimit(.minutes(1)))
            func respondsAndSends() async throws {
                _ = try await device.recordSync.sync()
                await device.reflection.finishedSyncs.reaches(2)

                await device.recordSync.respondToGoalSetupNotice()
                await device.reflection.finishedSyncs.reaches(3)

                #expect(device.store.cache.notices[GoalSetupNotice.noticeId]?.response != nil)
                #expect(device.store.entries.isEmpty)
            }
        }

        @Suite("サーバーが目標を立てる知らせを作る書き込みを断り、サーバーに知らせが無いとき")
        struct CreateRejected {
            let device: RecordSyncDevice

            init() throws {
                let clock = SteppingClock()
                device = try RecordSyncDevice(
                    clock: clock,
                    server: .passing(
                        .init(
                            records: [], startedOn: RecordSyncDevice.startedOn,
                            writePolicies: [RecordKindName.notice.serverName: .reject]),
                        clock: clock),
                    goals: [])
            }

            @Test("出して送るのを繰り返さず、送るための同期の1回で止まること", .timeLimit(.minutes(1)))
            func stopsAfterOneSend() async throws {
                _ = try await device.recordSync.sync()
                await device.reflection.finishedSyncs.reaches(2)
                // 繰り返していれば、ここで3回めの同期が始まる
                for _ in 0..<100 { await Task.yield() }

                #expect(device.server.pullTimes.count == 2)
                #expect(device.store.entries.isEmpty)
            }
        }

        @Suite("サーバーに目標があり、1日の目安と推定消費カロリーが目標より先に届くとき")
        struct GoalOnServer {
            let device: RecordSyncDevice
            let goalId = UUID()
            let guideId = UUID()
            let estimateId = UUID()

            init() throws {
                device = try GoalSetupNotice.device(records: [
                    .dailyGuide(
                        DailyGuideSyncingTests.synced(
                            id: guideId, goalId: goalId, expenditureEstimateId: estimateId)),
                    .expenditureEstimate(ExpenditureEstimateSyncingTests.synced(id: estimateId)),
                    .goal(try .maintaining(id: goalId)),
                ])
            }

            @Test("3つの種類の記録がキャッシュに入ること", .timeLimit(.minutes(1)))
            func storesThreeKinds() async throws {
                _ = try await device.recordSync.sync()

                #expect(Array(device.store.cache.goals.keys) == [goalId])
                #expect(device.store.cache.dailyGuides[guideId]?.goalId == goalId)
                #expect(Array(device.store.cache.expenditureEstimates.keys) == [estimateId])
            }

            @Test("目標を立てる知らせを作らないこと", .timeLimit(.minutes(1)))
            func doesNotIssueNotice() async throws {
                _ = try await device.recordSync.sync()

                #expect(device.store.cache.notices.isEmpty)
                #expect(device.store.entries.isEmpty)
            }
        }

        @Suite("3つの種類が読める版に上げて最初に開き、ほかの端末で立てた目標がサーバーにあるとき")
        struct FirstOpenAfterUpdateWithGoal {
            let device: RecordSyncDevice
            let goalId = UUID()

            init() throws {
                // 前の版は、通し番号 1 の目標を知らない種類として読み飛ばしている
                device = try GoalSetupNotice.device(
                    records: [.goal(try .maintaining(id: goalId))],
                    stateBeforeUpdate: (1, GoalSetupNotice.readableKindsBeforeUpdate))
            }

            @Test("全部取り直して目標を受け取り、目標を立てる知らせを作らないこと", .timeLimit(.minutes(1)))
            func pullsEverythingAgainAndDoesNotIssue() async throws {
                _ = try await device.recordSync.sync()

                #expect(Array(device.store.cache.goals.keys) == [goalId])
                #expect(device.store.cache.notices.isEmpty)
                #expect(device.store.entries.isEmpty)
            }
        }

        @Suite("3つの種類が読める版に上げて最初に開き、サーバーに目標が無いとき")
        struct FirstOpenAfterUpdateWithoutGoal {
            let device: RecordSyncDevice

            init() throws {
                device = try GoalSetupNotice.device(
                    records: [
                        .usualWeighingTime(SyncedUsualWeighingTime(id: UUID(), minuteOfDay: 435))
                    ],
                    stateBeforeUpdate: (1, GoalSetupNotice.readableKindsBeforeUpdate))
            }

            @Test("全部取り直したあとに、目標を立てる知らせを1つ作ること", .timeLimit(.minutes(1)))
            func issuesOneNoticeAfterPullingAgain() async throws {
                _ = try await device.recordSync.sync()

                #expect(device.store.cache.usualWeighingTime?.minuteOfDay == 435)
                #expect(Array(device.store.cache.notices.keys) == [GoalSetupNotice.noticeId])
            }

            @Test("そのあとの同期でも、知らせが二重にならないこと", .timeLimit(.minutes(1)))
            func keepsSingleNotice() async throws {
                _ = try await device.recordSync.sync()
                await device.reflection.finishedSyncs.reaches(2)
                _ = try await device.recordSync.sync()
                _ = try await device.recordSync.sync()

                #expect(Array(device.store.cache.notices.keys) == [GoalSetupNotice.noticeId])
                #expect(device.store.entries.isEmpty)
            }
        }

        @Suite("ほかの端末が作って答えた目標を立てる知らせが、サーバーにあるとき")
        struct AnsweredOnAnotherDevice {
            let device: RecordSyncDevice
            let answered: SyncedNotice

            init() throws {
                let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
                answered = SyncedNotice(
                    id: GoalSetupNotice.noticeId, noticeType: .goalSetup,
                    issuedAt: Date(timeIntervalSince1970: 1_790_028_900), timeZone: tokyo,
                    response: .init(
                        respondedAt: Date(timeIntervalSince1970: 1_790_029_800), timeZone: tokyo))
                device = try GoalSetupNotice.device(records: [.notice(answered)])
            }

            @Test("答えた形のまま受け取り、作り直さないこと", .timeLimit(.minutes(1)))
            func keepsAnsweredNotice() async throws {
                _ = try await device.recordSync.sync()

                #expect(
                    device.store.cache.notices[GoalSetupNotice.noticeId]?.response?.respondedAt
                        == answered.response?.respondedAt)
                #expect(device.store.entries.isEmpty)
            }
        }
    }
}
