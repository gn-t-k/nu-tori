import Foundation
import NuToriAPI
import NuToriCore
import Testing

@testable import NuTori

@Suite("いつもの時刻の種類")
struct UsualWeighingTimeRecordKindTests {
    @Suite("いつもの時刻がキャッシュにあり、別の値が届いたとき")
    @MainActor
    struct Replaced {
        let store: SwiftDataSyncStore
        let id: UUID

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            id = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1"))
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .usualWeighingTime,
                        changes: [.usualWeighingTime(.init(id: id, minuteOfDay: 435))])
                ]))
        }

        @Test("あとに届いた値で置き換え、1つだけ持つこと")
        func replacesUsualWeighingTime() async throws {
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .usualWeighingTime,
                        changes: [.usualWeighingTime(.init(id: id, minuteOfDay: 450))])
                ]))

            #expect(
                try await store.usualWeighingTime()
                    == UsualWeighingTime(id: id, minuteOfDay: 450))
        }
    }
}
