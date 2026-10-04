import Foundation
import NuToriCore
import NuToriTestSupport
import Synchronization
import Testing

@Suite("ヘルスケアとの同期の働き")
struct HealthSyncEngineTests {
    static let firstSampleId = "00000000-0000-4000-8000-0000000000c1"
    static let secondSampleId = "00000000-0000-4000-8000-0000000000c2"
    static let bodyFatSampleId = "00000000-0000-4000-8000-0000000000e1"

    static func recordId(ofSample sampleId: String) throws -> UUID {
        try ImportedWeightRecordId.make(healthKitSampleId: #require(UUID(uuidString: sampleId)))
    }

    @Suite("取り込む")
    struct Importing {
        @Suite("他のアプリの体重が増えたとき")
        struct AddedWeights {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    healthStore: .ok(
                        changes: .fixture(weights: [
                            try .fixture(
                                sampleId: HealthSyncEngineTests.firstSampleId, kilograms: 71.25)
                        ])
                    ),
                    store: store
                )
            }

            @Test("サンプルの UUID から作った ID で、取り込んだ記録として、キャッシュに入れること")
            func cachesImportedRecord() async throws {
                try await engine.importChanges()

                let record = try #require(store.records.values.first)
                #expect(store.records.count == 1)
                #expect(
                    record.id == (try HealthSyncEngineTests.recordId(ofSample: firstSampleId)))
                #expect(record.kilograms == 71.25)
                #expect(record.version == 1)
                #expect(
                    record.inputSource
                        == .imported(
                            WeightRecord.ImportedSource(
                                appName: "体重計アプリ",
                                bundleId: "com.example.scale",
                                healthKitSampleId: try #require(UUID(uuidString: firstSampleId)),
                                bodyFat: nil
                            )
                        )
                )
            }

            @Test("同じ保存で、作る書き込みを送り待ちに足し、アンカーを進めること")
            func enqueuesCreateWriteAndAdvancesAnchor() async throws {
                try await engine.importChanges()

                let record = try #require(store.records.values.first)
                #expect(store.pendingWeightRecords.map(\.write) == [.createWeightRecord(record)])
                #expect(
                    store.pendingWeightRecords.map(\.enqueuedAt) == [HealthSyncEngine.fixtureNow])
                #expect(store.healthState.anchor == HealthChanges.fixtureAnchor)
            }

            private var firstSampleId: String { HealthSyncEngineTests.firstSampleId }
        }

        @Suite("前回のアンカーがあるとき")
        struct WithAnchor {
            let healthStore: HealthStoreMock
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine
            let previousAnchor: HealthAnchor

            init() throws {
                previousAnchor = HealthAnchor(data: Data("anchor-1".utf8))
                healthStore = .ok(earliestAuthorizedSampleDate: Date(timeIntervalSince1970: 1_000))
                store = try .ok(
                    healthState: HealthSyncState(
                        anchor: previousAnchor, hasWrittenCachedManualRecords: true)
                )
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("前回の続きから、読み取りの期間の境界より前を読まずに読むこと")
            func readsFromAnchorNotBeforeBoundary() async throws {
                try await engine.importChanges()

                #expect(
                    healthStore.readRequests == [
                        .init(anchor: previousAnchor, notBefore: Date(timeIntervalSince1970: 1_000))
                    ])
            }

            @Test("書き込みの許可のあとにまとめて書き終えた印は、変えないこと")
            func keepsWrittenMark() async throws {
                try await engine.importChanges()

                #expect(store.healthState.hasWrittenCachedManualRecords)
            }
        }

        @Suite("初めて読むとき")
        struct FirstRead {
            let healthStore: HealthStoreMock
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine

            init() throws {
                healthStore = .ok()
                store = try .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("アンカー無しで、境界も無しで全期間を読むこと")
            func readsWholePeriod() async throws {
                try await engine.importChanges()

                #expect(healthStore.readRequests == [.init(anchor: nil, notBefore: nil)])
            }
        }

        @Suite("nu-tori 自身が書いた体重と、他のアプリの体重が混ざるとき")
        struct OwnSamples {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    healthStore: .ok(
                        changes: .fixture(
                            weights: [
                                try .fixture(
                                    sampleId: HealthSyncEngineTests.firstSampleId,
                                    sourceBundleId: HealthSyncEngine.ownBundleId),
                                try .fixture(sampleId: HealthSyncEngineTests.secondSampleId),
                            ],
                            bodyFats: [
                                try .fixture(
                                    sampleId: HealthSyncEngineTests.bodyFatSampleId,
                                    sourceBundleId: HealthSyncEngine.ownBundleId)
                            ]
                        )
                    ),
                    store: store
                )
            }

            @Test("出どころの bundle ID で、自分が書いた分を除くこと")
            func excludesOwnSamples() async throws {
                try await engine.importChanges()

                #expect(
                    store.records.keys.sorted { $0.uuidString < $1.uuidString } == [
                        try HealthSyncEngineTests.recordId(
                            ofSample: HealthSyncEngineTests.secondSampleId)
                    ])
            }
        }

        @Suite("範囲の外のサンプルが混ざるとき")
        struct OutOfRange {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    healthStore: .ok(
                        changes: .fixture(
                            weights: [
                                try .fixture(
                                    sampleId: HealthSyncEngineTests.firstSampleId, kilograms: 19.9),
                                try .fixture(
                                    sampleId: HealthSyncEngineTests.secondSampleId,
                                    kilograms: 70.0,
                                    at: "2026-09-25T07:12:00+09:00"),
                            ],
                            bodyFats: [
                                try .fixture(
                                    sampleId: HealthSyncEngineTests.bodyFatSampleId,
                                    fraction: 0.76,
                                    at: "2026-09-25T07:12:00+09:00")
                            ]
                        )
                    ),
                    store: store
                )
            }

            @Test("体重が範囲の外なら、送らず、キャッシュにも入れないこと")
            func dropsOutOfRangeWeight() async throws {
                try await engine.importChanges()

                #expect(
                    store.records[
                        try HealthSyncEngineTests.recordId(
                            ofSample: HealthSyncEngineTests.firstSampleId)]
                        == nil)
                #expect(store.pendingWeightRecords.count == 1)
            }

            @Test("体脂肪率だけが範囲の外なら、体脂肪率だけを落として体重は送ること")
            func dropsOnlyBodyFat() async throws {
                try await engine.importChanges()

                let record = try #require(
                    store.records[
                        try HealthSyncEngineTests.recordId(
                            ofSample: HealthSyncEngineTests.secondSampleId)])
                #expect(record.kilograms == 70.0)
                #expect(record.inputSource.importedBodyFat == nil)
            }
        }

        @Suite("体重と体脂肪率が届いたとき")
        struct BodyFatPairing {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    healthStore: .ok(
                        changes: .fixture(
                            weights: [
                                try .fixture(sampleId: HealthSyncEngineTests.firstSampleId),
                                try .fixture(
                                    sampleId: HealthSyncEngineTests.secondSampleId,
                                    at: "2026-09-25T07:12:00+09:00"),
                            ],
                            bodyFats: [
                                try .fixture(
                                    sampleId: HealthSyncEngineTests.bodyFatSampleId, fraction: 0.25),
                                try .fixture(
                                    sampleId: "00000000-0000-4000-8000-0000000000e2",
                                    fraction: 0.3,
                                    at: "2026-09-25T07:12:00+09:00",
                                    sourceBundleId: "com.example.other"),
                                try .fixture(
                                    sampleId: "00000000-0000-4000-8000-0000000000e3",
                                    fraction: 0.3,
                                    at: "2026-09-26T07:12:00+09:00"),
                            ]
                        )
                    ),
                    store: store
                )
            }

            @Test("同じ出どころで同じ時刻の体重に、% の値に直して、サンプルの UUID と一緒に添えること")
            func attachesPairedBodyFat() async throws {
                try await engine.importChanges()

                let record = try #require(
                    store.records[
                        try HealthSyncEngineTests.recordId(
                            ofSample: HealthSyncEngineTests.firstSampleId)])
                #expect(
                    record.inputSource.importedBodyFat
                        == WeightRecord.ImportedSource.BodyFat(
                            percentage: 25.0,
                            healthKitSampleId: try #require(
                                UUID(uuidString: HealthSyncEngineTests.bodyFatSampleId))
                        ))
            }

            @Test("出どころか時刻が違う体脂肪率は添えず、対になる体重の無い体脂肪率は送らないこと")
            func doesNotAttachUnpairedBodyFat() async throws {
                try await engine.importChanges()

                let second = try #require(
                    store.records[
                        try HealthSyncEngineTests.recordId(
                            ofSample: HealthSyncEngineTests.secondSampleId)])
                #expect(second.inputSource.importedBodyFat == nil)
                #expect(store.records.count == 2)
            }
        }

        @Suite("サンプルの時間帯のメタデータがあるものと無いものが届いたとき")
        struct TimeZones {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    healthStore: .ok(
                        changes: .fixture(weights: [
                            try .fixture(
                                sampleId: HealthSyncEngineTests.firstSampleId,
                                timeZoneIdentifier: "Europe/London"),
                            try .fixture(
                                sampleId: HealthSyncEngineTests.secondSampleId,
                                timeZoneIdentifier: nil),
                        ])
                    ),
                    store: store
                )
            }

            @Test("メタデータがあればそれを、無ければ取り込んだときの端末のタイムゾーンを、記録のタイムゾーンにすること")
            func decidesTimeZone() async throws {
                try await engine.importChanges()

                let withMetadata = try #require(
                    store.records[
                        try HealthSyncEngineTests.recordId(
                            ofSample: HealthSyncEngineTests.firstSampleId)])
                let withoutMetadata = try #require(
                    store.records[
                        try HealthSyncEngineTests.recordId(
                            ofSample: HealthSyncEngineTests.secondSampleId)])
                #expect(withMetadata.timeZone.identifier == "Europe/London")
                #expect(withoutMetadata.timeZone.identifier == "Asia/Tokyo")
            }
        }

        @Suite("キャッシュにもう同じ ID の記録があるサンプルを読み直したとき")
        struct AlreadyCached {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine
            let cached: WeightRecord

            init() throws {
                cached = try WeightRecord(
                    id: HealthSyncEngineTests.recordId(
                        ofSample: HealthSyncEngineTests.firstSampleId),
                    kilograms: 68.0,
                    instant: Date(timeIntervalSince1970: 1_767_225_600),
                    timeZone: #require(TimeZone(identifier: "Asia/Tokyo")),
                    inputSource: .imported(
                        WeightRecord.ImportedSource(
                            appName: "体重計アプリ",
                            bundleId: "com.example.scale",
                            healthKitSampleId: #require(
                                UUID(uuidString: HealthSyncEngineTests.firstSampleId)),
                            bodyFat: nil
                        )
                    ),
                    version: 3
                )
                store = try .ok(records: [cached])
                engine = .fixture(
                    healthStore: .ok(
                        changes: .fixture(weights: [
                            try .fixture(sampleId: HealthSyncEngineTests.firstSampleId)
                        ])
                    ),
                    store: store
                )
            }

            @Test("送らず、キャッシュの直した値も置き換えないこと")
            func keepsCacheAndSendsNothing() async throws {
                try await engine.importChanges()

                #expect(store.records[cached.id] == cached)
                #expect(store.pendingWeightRecords.isEmpty)
            }
        }

        @Suite("ヘルスケアで元のサンプルが消えたとき")
        struct Deleted {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine
            let cached: WeightRecord

            init() throws {
                cached = try WeightRecord(
                    id: HealthSyncEngineTests.recordId(
                        ofSample: HealthSyncEngineTests.firstSampleId),
                    kilograms: 68.0,
                    instant: Date(timeIntervalSince1970: 1_767_225_600),
                    timeZone: #require(TimeZone(identifier: "Asia/Tokyo")),
                    inputSource: .manual,
                    version: 1
                )
                store = try .ok(records: [cached])
                engine = .fixture(
                    healthStore: .ok(
                        changes: .fixture(deletions: [
                            .weight(
                                sampleId: try #require(
                                    UUID(uuidString: HealthSyncEngineTests.firstSampleId))),
                            .weight(
                                sampleId: try #require(
                                    UUID(uuidString: HealthSyncEngineTests.firstSampleId))),
                            .weight(
                                sampleId: try #require(
                                    UUID(uuidString: HealthSyncEngineTests.secondSampleId))),
                            .bodyFat(
                                sampleId: try #require(
                                    UUID(uuidString: HealthSyncEngineTests.bodyFatSampleId))),
                        ])
                    ),
                    store: store
                )
            }

            @Test("体重記録の ID を名指す消えた書き込みを、送り待ちに足すだけで、キャッシュは消さないこと")
            func enqueuesSourceDeletedWrites() async throws {
                try await engine.importChanges()

                #expect(
                    store.pendingWeightRecords.map(\.write) == [
                        .sourceDeletedWeightRecord(
                            recordId: try HealthSyncEngineTests.recordId(
                                ofSample: HealthSyncEngineTests.firstSampleId)),
                        .sourceDeletedWeightRecord(
                            recordId: try HealthSyncEngineTests.recordId(
                                ofSample: HealthSyncEngineTests.secondSampleId)),
                    ])
                #expect(store.records[cached.id] == cached)
            }

            @Test("体脂肪率のサンプルが消えた知らせは読み捨てること")
            func discardsBodyFatDeletions() async throws {
                try await engine.importChanges()

                #expect(store.pendingWeightRecords.count == 2)
            }
        }

        @Suite("読み取りの期間の境界より前の記録が、消えた分として返ったとき")
        struct DeletedBeforeBoundary {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine

            init() throws {
                let boundary = Date(timeIntervalSince1970: 1_767_225_600)
                let before = try WeightRecord(
                    id: HealthSyncEngineTests.recordId(
                        ofSample: HealthSyncEngineTests.firstSampleId),
                    kilograms: 68.0,
                    instant: boundary.addingTimeInterval(-1),
                    timeZone: #require(TimeZone(identifier: "Asia/Tokyo")),
                    inputSource: .manual,
                    version: 1
                )
                let after = try WeightRecord(
                    id: HealthSyncEngineTests.recordId(
                        ofSample: HealthSyncEngineTests.secondSampleId),
                    kilograms: 68.0,
                    instant: boundary,
                    timeZone: #require(TimeZone(identifier: "Asia/Tokyo")),
                    inputSource: .manual,
                    version: 1
                )
                store = try .ok(records: [before, after])
                engine = .fixture(
                    healthStore: .ok(
                        earliestAuthorizedSampleDate: boundary,
                        changes: .fixture(deletions: [
                            .weight(
                                sampleId: try #require(
                                    UUID(uuidString: HealthSyncEngineTests.firstSampleId))),
                            .weight(
                                sampleId: try #require(
                                    UUID(uuidString: HealthSyncEngineTests.secondSampleId))),
                        ])
                    ),
                    store: store
                )
            }

            @Test("境界より前は送らず、境界以降だけを送ること")
            func sendsOnlyOnOrAfterBoundary() async throws {
                try await engine.importChanges()

                #expect(
                    store.pendingWeightRecords.map(\.write) == [
                        .sourceDeletedWeightRecord(
                            recordId: try HealthSyncEngineTests.recordId(
                                ofSample: HealthSyncEngineTests.secondSampleId))
                    ])
            }
        }

        @Suite("体重が増え、別のサンプルが消えたとき")
        struct AddedAndDeleted {
            /// 読むたびに1秒進む時計
            final class TickingClock: Sendable {
                func now() -> Date {
                    ticks.withLock { ticks in
                        ticks += 1
                        return HealthSyncEngine.fixtureNow.addingTimeInterval(ticks)
                    }
                }

                private let ticks = Mutex(0.0)
            }

            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine

            init() throws {
                store = try .ok()
                let clock = TickingClock()
                engine = .fixture(
                    healthStore: .ok(
                        changes: .fixture(
                            weights: [try .fixture(sampleId: HealthSyncEngineTests.secondSampleId)],
                            deletions: [
                                .weight(
                                    sampleId: try #require(
                                        UUID(uuidString: HealthSyncEngineTests.firstSampleId)))
                            ]
                        )
                    ),
                    store: store,
                    now: { clock.now() }
                )
            }

            @Test("作る書き込みを先に、消えた書き込みを後に、書き込みごとの時刻で送り待ちに足すこと")
            func enqueuesInOrderWithOwnTimes() async throws {
                try await engine.importChanges()

                #expect(
                    store.pendingWeightRecords.map(\.write) == [
                        .createWeightRecord(try #require(store.records.values.first)),
                        .sourceDeletedWeightRecord(
                            recordId: try HealthSyncEngineTests.recordId(
                                ofSample: HealthSyncEngineTests.firstSampleId)),
                    ])
                #expect(
                    store.pendingWeightRecords.map(\.enqueuedAt) == [
                        HealthSyncEngine.fixtureNow.addingTimeInterval(1),
                        HealthSyncEngine.fixtureNow.addingTimeInterval(2),
                    ])
            }
        }

        @Suite("ヘルスケアの読み取りに失敗したとき")
        struct ReadFailure {
            struct Failure: Error, Equatable {}

            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(healthStore: .error(Failure()), store: store)
            }

            @Test("失敗を投げ、アンカーも送り待ちも進めないこと")
            func throwsWithoutAdvancing() async throws {
                await #expect(throws: Failure()) {
                    try await engine.importChanges()
                }
                #expect(store.saves.isEmpty)
            }
        }
    }

    @Suite("書き出す")
    struct Exporting {
        @Suite("書き込みの許可があるとき")
        struct Authorized {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine
            let manual: WeightRecord
            let imported: WeightRecord

            init() throws {
                manual = try .manual(
                    72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", version: 3)
                imported = try .imported(70.0, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: try .ok())
            }

            @Test("手で記録した体重を、体重記録の ID を同期 ID、版をヘルスケアの版にして書くこと")
            func writesManualRecord() async throws {
                try await engine.exportWeightRecord(manual)

                #expect(
                    healthStore.writes == [
                        HealthWeightWrite(
                            syncId: manual.id,
                            syncVersion: 3,
                            kilograms: 72.4,
                            instant: manual.instant,
                            timeZone: manual.timeZone
                        )
                    ])
            }

            @Test("取り込んだ体重は、直しても書かないこと")
            func doesNotWriteImportedRecord() async throws {
                try await engine.exportWeightRecord(imported)

                #expect(healthStore.writes.isEmpty)
            }
        }

        @Suite("書き込みの許可が無いとき")
        struct Unauthorized {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine
            let manual: WeightRecord

            init() throws {
                manual = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                healthStore = .ok(isWriteAuthorized: false)
                engine = .fixture(healthStore: healthStore, store: try .ok())
            }

            @Test("書かないこと")
            func doesNotWrite() async throws {
                try await engine.exportWeightRecord(manual)

                #expect(healthStore.writes.isEmpty)
            }
        }

        @Suite("書き込みの許可を得て、まとめて書いていないとき")
        struct NewlyAuthorized {
            let healthStore: HealthStoreMock
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine
            let firstManual: WeightRecord
            let secondManual: WeightRecord

            init() throws {
                firstManual = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                secondManual = try .manual(
                    72.0, at: "2026-09-25T07:12:00+09:00", in: "Asia/Tokyo", version: 2)
                healthStore = .ok()
                store = try .ok(
                    records: [
                        firstManual, secondManual,
                        try .imported(70.0, at: "2026-09-23T07:12:00+09:00", in: "Asia/Tokyo"),
                    ],
                    healthState: HealthSyncState(
                        anchor: HealthChanges.fixtureAnchor, hasWrittenCachedManualRecords: false)
                )
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("キャッシュにある手の記録だけを、まとめて書くこと")
            func writesCachedManualRecords() async throws {
                try await engine.exportCachedManualRecordsOnNewWriteAuthorization()

                #expect(Set(healthStore.writes.map(\.syncId)) == [firstManual.id, secondManual.id])
                #expect(healthStore.writes.first { $0.syncId == secondManual.id }?.syncVersion == 2)
            }

            @Test("書き終えた印を立て、アンカーは変えないこと")
            func marksAsWritten() async throws {
                try await engine.exportCachedManualRecordsOnNewWriteAuthorization()

                #expect(
                    store.healthState
                        == HealthSyncState(
                            anchor: HealthChanges.fixtureAnchor, hasWrittenCachedManualRecords: true
                        ))
            }

            @Test("2回目には書かないこと")
            func doesNotWriteTwice() async throws {
                try await engine.exportCachedManualRecordsOnNewWriteAuthorization()
                try await engine.exportCachedManualRecordsOnNewWriteAuthorization()

                #expect(healthStore.writes.count == 2)
            }
        }

        @Suite("書き込みの許可がまだ無いとき")
        struct NotYetAuthorized {
            let healthStore: HealthStoreMock
            let store: SyncBoxMock<RecordCacheMock>
            let engine: HealthSyncEngine

            init() throws {
                healthStore = .ok(isWriteAuthorized: false)
                store = try .ok(
                    records: [try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")])
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("あとで許可を得たときに書くために、書かず、書き終えた印も立てないこと")
            func waitsForAuthorization() async throws {
                try await engine.exportCachedManualRecordsOnNewWriteAuthorization()

                #expect(healthStore.writes.isEmpty)
                #expect(!store.healthState.hasWrittenCachedManualRecords)
            }
        }
    }

    @Suite("許可を求める時機")
    struct RequestingAuthorization {
        @Suite("初めて体重を入れるとき、この端末でまだ求めていなければ")
        struct FirstWeightEntryNotYetRequested {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                healthStore = .ok(requestStatus: .notYetRequested)
                engine = .fixture(healthStore: healthStore, store: try .ok())
            }

            @Test("求めること")
            func requests() async throws {
                try await engine.requestAuthorizationOnFirstWeightEntry()

                #expect(healthStore.authorizationRequests == 1)
            }
        }

        @Suite("初めて体重を入れるとき、この端末でもう求めていれば")
        struct FirstWeightEntryAlreadyRequested {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                healthStore = .ok(requestStatus: .alreadyRequested)
                engine = .fixture(healthStore: healthStore, store: try .ok())
            }

            @Test("求めないこと")
            func doesNotRequest() async throws {
                try await engine.requestAuthorizationOnFirstWeightEntry()

                #expect(healthStore.authorizationRequests == 0)
            }
        }

        @Suite("初回の取得を終え、アカウントに体重記録があり、この端末でまだ求めていなければ")
        struct AfterInitialPullWithRecords {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                healthStore = .ok(requestStatus: .notYetRequested)
                engine = .fixture(
                    healthStore: healthStore,
                    store: try .ok(
                        records: [
                            try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                        ],
                        state: .fixture(hasCompletedInitialPull: true)
                    )
                )
            }

            @Test("求めること")
            func requests() async throws {
                try await engine.requestAuthorizationAfterInitialPull()

                #expect(healthStore.authorizationRequests == 1)
            }
        }

        @Suite("初回の取得を終えたが、アカウントに体重記録が無ければ")
        struct AfterInitialPullWithoutRecords {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                healthStore = .ok(requestStatus: .notYetRequested)
                engine = .fixture(
                    healthStore: healthStore,
                    store: try .ok(state: .fixture(hasCompletedInitialPull: true))
                )
            }

            @Test("初めて体重を入れるときまで求めないこと")
            func doesNotRequest() async throws {
                try await engine.requestAuthorizationAfterInitialPull()

                #expect(healthStore.authorizationRequests == 0)
            }
        }

        @Suite("初回の取得をまだ終えていなければ")
        struct BeforeInitialPull {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                healthStore = .ok(requestStatus: .notYetRequested)
                engine = .fixture(
                    healthStore: healthStore,
                    store: try .ok(
                        records: [
                            try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                        ],
                        state: .fixture(hasCompletedInitialPull: false)
                    )
                )
            }

            @Test("求めないこと")
            func doesNotRequest() async throws {
                try await engine.requestAuthorizationAfterInitialPull()

                #expect(healthStore.authorizationRequests == 0)
            }
        }

        @Suite("初回の取得を終えたが、この端末でもう求めていれば")
        struct AfterInitialPullAlreadyRequested {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                healthStore = .ok(requestStatus: .alreadyRequested)
                engine = .fixture(
                    healthStore: healthStore,
                    store: try .ok(
                        records: [
                            try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                        ],
                        state: .fixture(hasCompletedInitialPull: true)
                    )
                )
            }

            @Test("求めないこと")
            func doesNotRequest() async throws {
                try await engine.requestAuthorizationAfterInitialPull()

                #expect(healthStore.authorizationRequests == 0)
            }
        }
    }
}

extension WeightRecord.InputSource {
    fileprivate var importedBodyFat: WeightRecord.ImportedSource.BodyFat? {
        switch self {
        case .manual: nil
        case .imported(let source): source.bodyFat
        }
    }
}
