import Foundation
import NuToriAPI
import NuToriCore
import Testing

@testable import NuTori

@Suite("いつもの時刻の種類")
@MainActor
struct UsualWeighingTimeRecordKindTests {
    let store: SwiftDataSyncStore

    init() throws {
        store = try SwiftDataSyncStore(inMemory: true)
    }

    @Test("いつもの時刻は、あとに届いた値で置き換え、1つだけ持つこと")
    func replacesUsualWeighingTime() async throws {
        let id = UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!

        for minuteOfDay in [435, 450] {
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .usualWeighingTime,
                        changes: [
                            .usualWeighingTime(.init(id: id, minuteOfDay: minuteOfDay))
                        ])
                ]))
        }

        #expect(
            try await store.usualWeighingTime()
                == UsualWeighingTime(id: id, minuteOfDay: 450))
    }
}
