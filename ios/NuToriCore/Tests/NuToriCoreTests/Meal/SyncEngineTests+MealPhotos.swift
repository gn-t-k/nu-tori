import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("食事の写真の同期")
    struct MealPhotoKind {
        @Suite("写真の食事を記録したとき")
        struct Recording {
            let uploader: MealPhotoUploaderMock
            let photos: MealPhotos
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let original: Data
            let edit: UserEdit

            init() throws {
                uploader = .ok()
                photos = .fixture(uploader: uploader)
                store = try .ok()
                engine = .fixture(store: store, transport: .sync(), mealPhotos: photos)
                original = Data([0x0A, 0x0B])
                edit = .recordingCapturedAtLunch(original)
            }

            @Test("元の大きさの写真をアプリの中に置き、食事の ID を添えて縮小版を裏で送り始めること")
            func keepsAndUploads() async throws {
                _ = try await engine.apply(edit, in: .gmt)

                let meal = try #require(store.cache.meals.values.first)
                let photoId = try #require(meal.photoIds.first)
                let file = try #require(await photos.photoFile(mealId: meal.id, photoId: photoId))
                #expect(try Data(contentsOf: file) == original)
                #expect(
                    uploader.started.map(\.upload)
                        == [MealPhotoUpload(mealId: meal.id, photoId: photoId)])
            }
        }

        @Suite("写真の送り残しがあるとき")
        struct PendingPhotos {
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() async throws {
                transport = .sync()
                engine = .fixture(store: try .ok(), transport: transport, mealPhotos: .fixture())
                for _ in 0..<2 {
                    _ = try await engine.apply(.recordingCapturedAtLunch(Data([0x01])), in: .gmt)
                }
            }

            @Test("送る要求と取りに行く要求に、写真の送り残しの数を添えること")
            func attachesPendingPhotoCount() async throws {
                _ = try await engine.sync()

                #expect(try transport.pushBodies.first?.clientState.pendingPhotoCount == 2)
                #expect(try transport.pullQueries.first?["pendingPhotoCount"] == "2")
            }
        }

        @Suite("食事の削除の印が届いたとき")
        struct PulledDeletion {
            let uploader: MealPhotoUploaderMock
            let photos: MealPhotos
            let engine: SyncEngine
            let meal: Meal

            init() async throws {
                uploader = .ok()
                photos = .fixture(uploader: uploader)
                let store = try SyncBoxMock<RecordCacheMock>.ok()
                _ = try await SyncEngine.fixture(
                    store: store, transport: .error(URLError(.notConnectedToInternet)),
                    mealPhotos: photos
                ).apply(.recordingCapturedAtLunch(Data([0x01])), in: .gmt)
                meal = try #require(store.cache.meals.values.first)
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"meal_deletion","recordId":"\(meal.id.uuidString)","record":{}}
                        ],"hasMore":false,"nextAfterSequence":1,"startedOn":null}
                        """
                    ]),
                    mealPhotos: photos)
            }

            @Test("その食事のアプリの中の写真を消し、写真の送り残しを取り消すこと")
            func discardsPhotos() async throws {
                _ = try await engine.sync()

                let photoId = try #require(meal.photoIds.first)
                #expect(await photos.photoFile(mealId: meal.id, photoId: photoId) == nil)
                #expect(await photos.pendingUploadCount() == 0)
                #expect(uploader.cancelledMealIds == [meal.id])
            }
        }

        @Suite("サーバーが作る書き込みを受け付けず、サーバーに食事が無いとき")
        struct RejectedWithoutValue {
            let uploader: MealPhotoUploaderMock
            let photos: MealPhotos
            let engine: SyncEngine
            let meal: Meal

            init() async throws {
                uploader = .ok()
                photos = .fixture(uploader: uploader)
                let store = try SyncBoxMock<RecordCacheMock>.ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(rejectedWriteIndexes: [0], currents: [0: .absent]),
                    mealPhotos: photos)
                _ = try await engine.apply(.recordingCapturedAtLunch(Data([0x01])), in: .gmt)
                meal = try #require(store.cache.meals.values.first)
            }

            @Test("その食事のアプリの中の写真を消し、写真の送り残しを取り消すこと")
            func discardsPhotos() async throws {
                _ = try await engine.sync()

                let photoId = try #require(meal.photoIds.first)
                #expect(await photos.photoFile(mealId: meal.id, photoId: photoId) == nil)
                #expect(await photos.pendingUploadCount() == 0)
                #expect(uploader.cancelledMealIds == [meal.id])
            }
        }

        @Suite("この端末で食事を消したとき")
        struct DeletingOnThisDevice {
            let uploader: MealPhotoUploaderMock
            let photos: MealPhotos
            let engine: SyncEngine
            let meal: Meal
            let card: MealCard

            init() async throws {
                uploader = .ok()
                photos = .fixture(uploader: uploader)
                let store = try SyncBoxMock<RecordCacheMock>.ok()
                engine = .fixture(
                    store: store, transport: .error(URLError(.notConnectedToInternet)),
                    mealPhotos: photos)
                _ = try await engine.apply(.recordingCapturedAtLunch(Data([0x01])), in: .gmt)
                meal = try #require(store.cache.meals.values.first)
                card = MealCard(meal: meal, status: nil, recordedOnThisDevice: true)
            }

            @Test("つながらなくても、その食事のアプリの中の写真を消し、写真の送り残しを取り消すこと")
            func discardsPhotos() async throws {
                _ = try await engine.apply(
                    .deleteMeal(card, deletedAt: SyncEngine.fixtureNow), in: .gmt)

                let photoId = try #require(meal.photoIds.first)
                #expect(await photos.photoFile(mealId: meal.id, photoId: photoId) == nil)
                #expect(await photos.pendingUploadCount() == 0)
                #expect(uploader.cancelledMealIds == [meal.id])
            }
        }
    }
}

extension UserEdit {
    /// 2026-09-22 12:10（東京）に撮り、1分後に送った食事を、元の写真 `original` で記録する
    fileprivate static func recordingCapturedAtLunch(_ original: Data) -> UserEdit {
        .recordCapturedMeal(
            MealPhotoOriginal(
                data: original,
                exif: .takenAt(
                    PhotoExif.WallClock(
                        year: 2026, month: 9, day: 22, hour: 12, minute: 10, second: 0),
                    utcOffsetSeconds: 32_400)),
            sentAt: Date(timeIntervalSince1970: 1_790_046_660))
    }
}
