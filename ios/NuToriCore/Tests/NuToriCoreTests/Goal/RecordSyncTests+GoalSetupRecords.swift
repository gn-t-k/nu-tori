import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension RecordSyncTests {
    @Suite("目標の設定の流れが頼むこと")
    struct GoalSetupRecordsTests {
        static let tokyo = TimeZone(identifier: "Asia/Tokyo")!

        static func device(connection: FakeSyncServer.Connection, goals: [Goal])
            throws -> RecordSyncDevice
        {
            let clock = SteppingClock()
            return try RecordSyncDevice(
                clock: clock,
                server: .passing(
                    .init(records: [], startedOn: RecordSyncDevice.startedOn, connection: connection),
                    clock: clock),
                goals: goals)
        }

        @Suite("目標が無いとき")
        struct NoGoal {
            let device: RecordSyncDevice

            init() throws {
                device = try GoalSetupRecordsTests.device(connection: .online, goals: [])
            }

            @Test("初めての目標で、使い始めた日と体重の記録が無いことを返すこと")
            func startsFirstGoal() async throws {
                let start = try await device.recordSync.goalSetupStart(
                    today: CalendarDay(year: 2026, month: 10, day: 14))

                #expect(
                    start
                        == .first(
                            firstUseDay: CalendarDay(year: 2026, month: 9, day: 22),
                            hasWeightRecords: false))
            }
        }

        @Suite("閉じていない目標があるとき")
        struct CurrentGoal {
            let device: RecordSyncDevice

            init() throws {
                device = try GoalSetupRecordsTests.device(connection: .online, goals: [.losing()])
            }

            @Test("立て直しで、今の目標の開始の日を返すこと")
            func startsRestart() async throws {
                let start = try await device.recordSync.goalSetupStart(
                    today: CalendarDay(year: 2026, month: 10, day: 14))

                #expect(start == .restart(currentGoalStartedDay: CalendarDay(year: 2026, month: 10, day: 1)))
            }
        }

        @Suite("つながるとき、足りない値で入れた今の体重を記録したら")
        struct RecordedWeightOnline {
            let device: RecordSyncDevice

            init() throws {
                device = try GoalSetupRecordsTests.device(connection: .online, goals: [])
            }

            @Test("今日の体重記録をキャッシュに置き、送り切ったと返すこと", .timeLimit(.minutes(1)))
            func sendsWeightRecord() async throws {
                try await device.recordSync.recordWeight(
                    kilograms: 70.2, at: Date(timeIntervalSince1970: 1_790_000_000),
                    in: GoalSetupRecordsTests.tokyo)

                let sent = await device.recordSync.sendWeightRecordsForGoalSetup()

                #expect(sent)
                #expect(device.store.cache.records.values.map(\.kilograms) == [70.2])
                #expect(device.store.entries.isEmpty)
            }
        }

        @Suite("電波が無いとき、足りない値で入れた今の体重を記録したら")
        struct RecordedWeightOffline {
            let device: RecordSyncDevice

            init() throws {
                device = try GoalSetupRecordsTests.device(connection: .offline, goals: [])
            }

            @Test("送り待ちに残し、送り切れなかったと返すこと", .timeLimit(.minutes(1)))
            func keepsPending() async throws {
                try? await device.recordSync.recordWeight(
                    kilograms: 70.2, at: Date(timeIntervalSince1970: 1_790_000_000),
                    in: GoalSetupRecordsTests.tokyo)

                let sent = await device.recordSync.sendWeightRecordsForGoalSetup()

                #expect(!sent)
                #expect(device.store.entries.map(\.kind) == [.weightRecord])
            }
        }

        @Suite("目標を決める要求の応答の記録を当てたとき")
        struct AppliedDecision {
            let device: RecordSyncDevice
            let goalId: UUID

            init() throws {
                device = try GoalSetupRecordsTests.device(connection: .online, goals: [])
                goalId = UUID()
            }

            @Test("目標をキャッシュに書くこと")
            func writesGoal() async throws {
                try await device.recordSync.applyGoalDecision([.goal(try .losing(id: goalId))])

                #expect(device.store.cache.goals[goalId]?.targetWeightKilograms == 68.0)
            }
        }
    }
}
