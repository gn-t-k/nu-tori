import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("アプリの中の食事の写真")
struct MealPhotosTests {
    @Suite("写真を置いたとき")
    struct Keeping {
        let folders: MealPhotos.Folders
        let uploader: MealPhotoUploaderMock
        let photos: MealPhotos
        let meal: Meal
        let original: Data

        init() throws {
            folders = .temporary()
            uploader = .ok()
            photos = .fixture(folders: folders, uploader: uploader)
            meal = try .withPhotos(count: 1)
            original = Data([0x01, 0x02, 0x03])
        }

        @Test("元の大きさの写真を、元の写真の置き場に置くこと")
        func keepsOriginal() async throws {
            let photoId = try #require(meal.photoIds.first)

            try await photos.keep([photoId: original], of: meal)

            let file = try #require(await photos.photoFile(mealId: meal.id, photoId: photoId))
            #expect(try Data(contentsOf: file) == original)
            #expect(file.path().hasPrefix(folders.originals.path()))
        }

        @Test("縮小版をファイルに書き、写真の ID の経路に裏で送り始めること")
        func startsUploadingThumbnail() async throws {
            let photoId = try #require(meal.photoIds.first)

            try await photos.keep([photoId: original], of: meal)

            let started = try #require(uploader.started.first)
            #expect(started.upload == MealPhotoUpload(mealId: meal.id, photoId: photoId))
            #expect(try Data(contentsOf: started.file) == MealPhotos.downscaled(original))
            #expect(started.request.method == "PUT")
            #expect(started.request.url.path() == "/v1/meal-photos/\(photoId.uuidString)")
            #expect(started.request.headerFields["Authorization"] == "Bearer session-1")
        }

        @Test("写真の送り残しに数えること")
        func countsPendingUpload() async throws {
            try await photos.keep([try #require(meal.photoIds.first): original], of: meal)

            #expect(await photos.pendingUploadCount() == 1)
        }
    }

    @Suite("食事の写真の元の写真が欠けているとき")
    struct KeepingWithoutOriginal {
        let uploader: MealPhotoUploaderMock
        let photos: MealPhotos
        let meal: Meal

        init() throws {
            uploader = .ok()
            photos = .fixture(uploader: uploader)
            meal = try .withPhotos(count: 2)
        }

        @Test("置かずに投げること")
        func throwsWithoutKeeping() async throws {
            let photoId = try #require(meal.photoIds.first)

            await #expect(throws: MealPhotos.MissingOriginalError.self) {
                try await photos.keep([photoId: Data([0x01])], of: meal)
            }
            #expect(uploader.started.isEmpty)
            #expect(await photos.pendingUploadCount() == 0)
        }
    }

    @Suite("App スイッチャーで閉じて、送っている途中の送信が無くなったあと、開き直したとき")
    struct ResendingAfterClosed {
        let uploader: MealPhotoUploaderMock
        let photos: MealPhotos
        let interrupted: Meal
        let stillSending: Meal

        init() async throws {
            uploader = .ok()
            photos = .fixture(uploader: uploader)
            interrupted = try .withPhotos(count: 2)
            stillSending = try .withPhotos(count: 1)
            try await photos.keep(.originals(of: interrupted), of: interrupted)
            uploader.dropAllInFlight()
            try await photos.keep(.originals(of: stillSending), of: stillSending)
        }

        @Test("送っている途中でない送り残しだけを送り直すこと")
        func resendsOnlyInterrupted() async throws {
            let before = uploader.started.count

            await photos.resendPendingUploads()

            #expect(
                Set(uploader.started.dropFirst(before).map(\.upload))
                    == Set(
                        interrupted.photoIds.map {
                            MealPhotoUpload(mealId: interrupted.id, photoId: $0)
                        }))
        }
    }

    @Suite("裏で送った結果が届いたとき")
    struct Finishing {
        @Suite("サーバーが受け取ったとき")
        struct Delivered {
            let uploader: MealPhotoUploaderMock
            let errorReporting: ErrorReportingSessionMock
            let photos: MealPhotos
            let meal: Meal

            init() async throws {
                uploader = .ok()
                errorReporting = .ok()
                photos = .fixture(uploader: uploader, errorReporting: errorReporting)
                meal = try .withPhotos(count: 2)
                try await photos.keep(.originals(of: meal), of: meal)
            }

            @Test("送り残しから外し、送り直さないこと")
            func removesFromPending() async throws {
                let upload = try #require(uploader.started.first).upload
                uploader.finish(upload)

                _ = await photos.finishUpload(upload, with: .responded(statusCode: 204))
                let before = uploader.started.count
                await photos.resendPendingUploads()

                #expect(await photos.pendingUploadCount() == 1)
                #expect(uploader.started.count == before)
                #expect(errorReporting.reported.isEmpty)
            }

            @Test("その食事の写真をすべて送り終えたときだけ、送り終えたと返すこと")
            func returnsDeliveredWhenMealIsDone() async throws {
                let first = try #require(uploader.started.first).upload
                let second = try #require(uploader.started.last).upload

                let afterFirst = await photos.finishUpload(first, with: .responded(statusCode: 204))
                let afterSecond = await photos.finishUpload(
                    second, with: .responded(statusCode: 204))

                #expect(!afterFirst)
                #expect(afterSecond)
            }
        }

        @Suite("サーバーが受け取れなかったとき")
        struct ServerFailed {
            let uploader: MealPhotoUploaderMock
            let errorReporting: ErrorReportingSessionMock
            let photos: MealPhotos
            let upload: MealPhotoUpload

            init() async throws {
                uploader = .ok()
                errorReporting = .ok()
                photos = .fixture(uploader: uploader, errorReporting: errorReporting)
                let meal = try Meal.withPhotos(count: 1)
                try await photos.keep(.originals(of: meal), of: meal)
                upload = try #require(uploader.started.first).upload
                uploader.finish(upload)
            }

            @Test("送り残しに残し、開き直したときに送り直すこと")
            func keepsForResend() async throws {
                _ = await photos.finishUpload(upload, with: .responded(statusCode: 500))
                await photos.resendPendingUploads()

                #expect(await photos.pendingUploadCount() == 1)
                #expect(uploader.started.map(\.upload) == [upload, upload])
            }

            @Test("写真の送信の失敗を Sentry に送ること")
            func reports() async throws {
                _ = await photos.finishUpload(upload, with: .responded(statusCode: 500))

                #expect(errorReporting.reported == [.photoUpload])
            }
        }

        @Suite("サーバーが大きすぎると断ったとき")
        struct TooLarge {
            let errorReporting: ErrorReportingSessionMock
            let photos: MealPhotos
            let upload: MealPhotoUpload

            init() async throws {
                let uploader = MealPhotoUploaderMock.ok()
                errorReporting = .ok()
                photos = .fixture(uploader: uploader, errorReporting: errorReporting)
                let meal = try Meal.withPhotos(count: 1)
                try await photos.keep(.originals(of: meal), of: meal)
                upload = try #require(uploader.started.first).upload
            }

            @Test("送り直しても受け取られないので、送り残しから外して Sentry に送ること")
            func abandonsAndReports() async throws {
                let delivered = await photos.finishUpload(
                    upload, with: .responded(statusCode: 413))

                #expect(!delivered)
                #expect(await photos.pendingUploadCount() == 0)
                #expect(errorReporting.reported == [.photoUpload])
            }
        }

        @Suite("セッションが切れていたとき")
        struct SessionExpired {
            let errorReporting: ErrorReportingSessionMock
            let photos: MealPhotos
            let upload: MealPhotoUpload

            init() async throws {
                let uploader = MealPhotoUploaderMock.ok()
                errorReporting = .ok()
                photos = .fixture(uploader: uploader, errorReporting: errorReporting)
                let meal = try Meal.withPhotos(count: 1)
                try await photos.keep(.originals(of: meal), of: meal)
                upload = try #require(uploader.started.first).upload
            }

            @Test("送り残しに残し、Sentry に送らないこと")
            func keepsWithoutReport() async throws {
                _ = await photos.finishUpload(upload, with: .responded(statusCode: 401))

                #expect(await photos.pendingUploadCount() == 1)
                #expect(errorReporting.reported.isEmpty)
            }
        }

        @Suite("つながらないとき")
        struct Unreachable {
            let errorReporting: ErrorReportingSessionMock
            let photos: MealPhotos
            let upload: MealPhotoUpload

            init() async throws {
                let uploader = MealPhotoUploaderMock.ok()
                errorReporting = .ok()
                photos = .fixture(uploader: uploader, errorReporting: errorReporting)
                let meal = try Meal.withPhotos(count: 1)
                try await photos.keep(.originals(of: meal), of: meal)
                upload = try #require(uploader.started.first).upload
            }

            @Test("送り残しに残し、Sentry に送らないこと")
            func keepsWithoutReport() async throws {
                _ = await photos.finishUpload(
                    upload, with: .failed(URLError(.notConnectedToInternet)))

                #expect(await photos.pendingUploadCount() == 1)
                #expect(errorReporting.reported.isEmpty)
            }
        }

        @Suite("時間切れのとき")
        struct TimedOut {
            let errorReporting: ErrorReportingSessionMock
            let photos: MealPhotos
            let upload: MealPhotoUpload

            init() async throws {
                let uploader = MealPhotoUploaderMock.ok()
                errorReporting = .ok()
                photos = .fixture(uploader: uploader, errorReporting: errorReporting)
                let meal = try Meal.withPhotos(count: 1)
                try await photos.keep(.originals(of: meal), of: meal)
                upload = try #require(uploader.started.first).upload
            }

            @Test("Sentry に送らないこと")
            func doesNotReport() async throws {
                _ = await photos.finishUpload(upload, with: .failed(URLError(.timedOut)))

                #expect(errorReporting.reported.isEmpty)
            }
        }

        @Suite("送信が取り消されたとき")
        struct Cancelled {
            let errorReporting: ErrorReportingSessionMock
            let photos: MealPhotos
            let upload: MealPhotoUpload

            init() async throws {
                let uploader = MealPhotoUploaderMock.ok()
                errorReporting = .ok()
                photos = .fixture(uploader: uploader, errorReporting: errorReporting)
                let meal = try Meal.withPhotos(count: 1)
                try await photos.keep(.originals(of: meal), of: meal)
                upload = try #require(uploader.started.first).upload
            }

            @Test("送り残しに残し、Sentry に送らないこと")
            func keepsWithoutReport() async throws {
                _ = await photos.finishUpload(upload, with: .failed(URLError(.cancelled)))

                #expect(await photos.pendingUploadCount() == 1)
                #expect(errorReporting.reported.isEmpty)
            }
        }
    }

    @Suite("この端末で記録した食事かを見るとき")
    struct RecordedOnThisDevice {
        let photos: MealPhotos
        let recorded: Meal
        let fromAnotherDevice: Meal

        init() async throws {
            photos = .fixture()
            recorded = try .withPhotos(count: 1)
            fromAnotherDevice = try .withPhotos(count: 1)
            try await photos.keep(.originals(of: recorded), of: recorded)
        }

        @Test("元の大きさの写真を置いた食事だけを、この端末で記録した食事とすること")
        func holdsOnlyRecorded() async throws {
            #expect(await photos.holdsOriginals(ofMeal: recorded.id))
            #expect(await !photos.holdsOriginals(ofMeal: fromAnotherDevice.id))
        }
    }

    @Suite("写真を持たない端末で、写真を見せるとき")
    struct ShowingOnAnotherDevice {
        let folders: MealPhotos.Folders
        let transport: ClientTransportMock
        let photos: MealPhotos
        let meal: Meal
        let thumbnail: Data

        init() throws {
            folders = .temporary()
            meal = try .withPhotos(count: 1)
            thumbnail = Data([0xFF, 0xD8, 0xFF, 0xD9])
            transport = .mealPhotos([try #require(meal.photoIds.first): thumbnail])
            photos = .fixture(folders: folders, transport: transport)
        }

        @Test("縮小版を取りに行き、消えてもよいキャッシュの置き場に置いて返すこと")
        func fetchesIntoCache() async throws {
            let photoId = try #require(meal.photoIds.first)

            let file = try #require(await photos.photoFile(mealId: meal.id, photoId: photoId))

            #expect(try Data(contentsOf: file) == thumbnail)
            #expect(file.path().hasPrefix(folders.fetched.path()))
        }

        @Test("二度目は取りに行かないこと")
        func fetchesOnce() async throws {
            let photoId = try #require(meal.photoIds.first)

            _ = await photos.photoFile(mealId: meal.id, photoId: photoId)
            _ = await photos.photoFile(mealId: meal.id, photoId: photoId)

            #expect(transport.requests.count == 1)
        }

        @Test("写真の送り残しには数えないこと")
        func doesNotCountAsPending() async throws {
            _ = await photos.photoFile(mealId: meal.id, photoId: try #require(meal.photoIds.first))

            #expect(await photos.pendingUploadCount() == 0)
        }
    }

    @Suite("写真を持たない端末で、サーバーがまだ写真を受け取っていないとき")
    struct ShowingBeforeServerReceived {
        let photos: MealPhotos
        let meal: Meal

        init() throws {
            photos = .fixture(transport: .mealPhotos([:]))
            meal = try .withPhotos(count: 1)
        }

        @Test("写真が無いと返すこと")
        func returnsNil() async throws {
            let file = await photos.photoFile(
                mealId: meal.id, photoId: try #require(meal.photoIds.first))

            #expect(file == nil)
        }
    }

    @Suite("食事の写真を消したとき")
    struct Discarding {
        let uploader: MealPhotoUploaderMock
        let transport: ClientTransportMock
        let photos: MealPhotos
        let discarded: Meal
        let kept: Meal
        let fetched: Meal

        init() async throws {
            uploader = .ok()
            discarded = try .withPhotos(count: 2)
            kept = try .withPhotos(count: 1)
            fetched = try .withPhotos(count: 1)
            transport = .mealPhotos([try #require(fetched.photoIds.first): Data([0xFF])])
            photos = .fixture(uploader: uploader, transport: transport)
            try await photos.keep(.originals(of: discarded), of: discarded)
            try await photos.keep(.originals(of: kept), of: kept)
            _ = await photos.photoFile(
                mealId: fetched.id, photoId: try #require(fetched.photoIds.first))
        }

        @Test("元の大きさの写真と縮小版を消し、送り残しを取り消すこと")
        func removesOwnPhotos() async throws {
            await photos.discardPhotos(ofMeal: discarded.id)

            #expect(uploader.cancelledMealIds == [discarded.id])
            #expect(await photos.pendingUploadCount() == 1)
            let photoId = try #require(discarded.photoIds.first)
            #expect(await photos.photoFile(mealId: discarded.id, photoId: photoId) == nil)
        }

        @Test("取りに行った縮小版を消すこと")
        func removesFetchedThumbnail() async throws {
            let photoId = try #require(fetched.photoIds.first)
            let before = transport.requests.count

            await photos.discardPhotos(ofMeal: fetched.id)
            _ = await photos.photoFile(mealId: fetched.id, photoId: photoId)

            #expect(transport.requests.count == before + 1)
        }

        @Test("ほかの食事の写真は残すこと")
        func keepsOtherMeals() async throws {
            await photos.discardPhotos(ofMeal: discarded.id)

            let photoId = try #require(kept.photoIds.first)
            #expect(await photos.photoFile(mealId: kept.id, photoId: photoId) != nil)
        }
    }

    @Suite("アカウントの削除で")
    struct DeletingAccount {
        let uploader: MealPhotoUploaderMock
        let photos: MealPhotos
        let meal: Meal

        init() async throws {
            uploader = .ok()
            photos = .fixture(uploader: uploader)
            meal = try .withPhotos(count: 1)
            try await photos.keep(.originals(of: meal), of: meal)
        }

        @Test("削除の経路を呼ぶ前の取り消しでは、裏の送信だけを取り消し、写真と送り残しを残すこと")
        func cancelsUploadsOnly() async throws {
            await photos.cancelUploads()

            #expect(uploader.cancelAllCount == 1)
            #expect(await photos.pendingUploadCount() == 1)
        }

        @Test("端末から消すときは、裏の送信を取り消し、写真と送り残しを消すこと")
        func erasesEverything() async throws {
            try await photos.cancelAndDeleteAll()

            #expect(uploader.cancelAllCount == 1)
            #expect(await photos.pendingUploadCount() == 0)
            let photoId = try #require(meal.photoIds.first)
            #expect(await photos.photoFile(mealId: meal.id, photoId: photoId) == nil)
        }
    }
}

extension Meal {
    /// 写真の ID を `count` 枚振った、撮った食事
    static func withPhotos(count: Int) throws -> Meal {
        Meal(
            id: UUID(),
            eatenAt: Date(timeIntervalSince1970: 1_790_046_600),
            eatenUtcOffsetSeconds: 9 * 3600,
            sentAt: Date(timeIntervalSince1970: 1_790_046_660),
            sentTimeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            entry: .captured,
            photoIds: (0..<count).map { _ in UUID() }
        )
    }
}

extension [UUID: Data] {
    /// 食事の写真の ID ごとの、元の大きさの写真
    static func originals(of meal: Meal) -> [UUID: Data] {
        Dictionary(uniqueKeysWithValues: meal.photoIds.map { ($0, Data($0.uuidString.utf8)) })
    }
}
