import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("いつもの時刻の同期")
    struct UsualWeighingTimeKind {
        static let timeId = "00000000-0000-4000-8000-0000000000b1"

        static func change(sequence: Int, minuteOfDay: Int) -> String {
            """
            {"sequence":\(sequence),"kind":"usual_weighing_time","recordId":"\(timeId)",
             "record":{"minuteOfDay":\(minuteOfDay)}}
            """
        }

        @Suite("1つの頁にいつもの時刻が2回届いたとき")
        struct PullingTwice {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          \(UsualWeighingTimeKind.change(sequence: 1, minuteOfDay: 435)),
                          \(UsualWeighingTimeKind.change(sequence: 2, minuteOfDay: 450))
                        ],"hasMore":false,"nextAfterSequence":2,"startedOn":null}
                        """
                    ]))
            }

            @Test("あとに届いた時刻をキャッシュに持つこと")
            func keepsLatest() async throws {
                _ = try await engine.sync()

                #expect(
                    store.cache.usualWeighingTime
                        == UsualWeighingTime(
                            id: try #require(UUID(uuidString: UsualWeighingTimeKind.timeId)),
                            minuteOfDay: 450))
            }
        }

        @Suite("いつもの時刻を持っていて、いつもの時刻の届かない頁を取りに行ったとき")
        struct PullingWithoutChange {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[\(UsualWeighingTimeKind.change(sequence: 1, minuteOfDay: 435))],
                         "hasMore":false,"nextAfterSequence":1,"startedOn":null}
                        """,
                        #"{"changes":[],"hasMore":false,"nextAfterSequence":1,"startedOn":null}"#,
                    ]))
                _ = try await engine.sync()
            }

            @Test("持っている時刻を消さないこと")
            func keepsCachedTime() async throws {
                _ = try await engine.sync()

                #expect(store.cache.usualWeighingTime?.minuteOfDay == 435)
            }
        }
    }
}
