public import Foundation
public import NuToriAPI

/// アプリの中の食事の写真と、写真の送り残し。
/// 元の大きさの写真、送る縮小版（写真の送り残し）、取りに行った縮小版を、置き場ごとに食事の ID のフォルダに分けて置く
public actor MealPhotos: BackgroundTransferStore {
    /// `downscale` は、元の写真から縮小版（長辺 1024px、EXIF なしの JPEG）を作る
    public init(
        folders: Folders,
        uploader: any MealPhotoUploader,
        downscale: @escaping @Sendable (Data) throws -> Data,
        client: NuToriAPIClient,
        errorReporting: any ErrorReportingSession
    ) {
        self.folders = folders
        self.uploader = uploader
        self.downscale = downscale
        self.client = client
        self.errorReporting = errorReporting
    }

    public struct Folders: Sendable {
        /// 元の大きさの写真。iPhone のバックアップの対象になる場所
        public let originals: URL
        /// 送る縮小版。サーバーに届いたと分かるまで残すので、バックアップの対象になる場所
        public let uploads: URL
        /// 取りに行った縮小版。消えても取りに行き直せるので、システムが空けてよい場所
        public let fetched: URL

        public init(originals: URL, uploads: URL, fetched: URL) {
            self.originals = originals
            self.uploads = uploads
            self.fetched = fetched
        }
    }

    public struct MissingOriginalError: Error, Equatable {
        public let photoId: UUID
    }

    /// 撮った・選んだ写真を置き、縮小版を書いて裏で送り始める。`originals` は写真の ID ごとの元の写真
    public func keep(_ originals: [UUID: Data], of meal: Meal) async throws {
        let photos = try meal.photoIds.map { photoId in
            guard let original = originals[photoId] else {
                throw MissingOriginalError(photoId: photoId)
            }
            return (photoId: photoId, original: original)
        }
        do {
            for photo in photos {
                let upload = MealPhotoUpload(mealId: meal.id, photoId: photo.photoId)
                try write(photo.original, to: originalFile(of: upload))
                try write(try downscale(photo.original), to: uploadFile(of: upload))
            }
        } catch {
            removeFolders(ofMeal: meal.id)
            throw error
        }
        for photoId in meal.photoIds {
            await startUpload(MealPhotoUpload(mealId: meal.id, photoId: photoId))
        }
    }

    /// この端末で記録した（元の大きさの写真を持っている）食事か。`MealCard` の `recordedOnThisDevice` に渡す
    public func holdsOriginals(ofMeal mealId: UUID) -> Bool {
        Self.exists(folders.originals.appending(path: mealId.uuidString))
    }

    /// 写真の送り残しの数
    public func pendingUploadCount() -> Int {
        pendingUploads().count
    }

    /// その食事の写真（元の大きさ、縮小版、取りに行った縮小版）を消し、送り残しを取り消す。
    /// 消せなくても、記録と同期は止めない。残ったファイルは、アカウントを消すときに消える
    public func discardPhotos(ofMeal mealId: UUID) async {
        discardedMealIds.insert(mealId)
        await uploader.cancelUploads(ofMeal: mealId)
        removeFolders(ofMeal: mealId)
    }

    /// 送っている途中でない送り残しを、送り直す。App スイッチャーで閉じると送信が取り消されるため、開いたときに呼ぶ
    public func resendPendingUploads() async {
        let inFlight = await uploader.uploadsInFlight()
        for upload in pendingUploads() where !inFlight.contains(upload) {
            await startUpload(upload)
        }
    }

    /// 裏で送った結果を当てる。その食事の写真の送り残しが無くなったら true を返す
    public func finishUpload(_ upload: MealPhotoUpload, with result: MealPhotoUploadResult) async
        -> Bool
    {
        if let failure = Self.reportedFailure(of: result) {
            await errorReporting.report(failure)
        }
        switch UploadOutcome(result) {
        case .delivered:
            try? FileManager.default.removeItem(at: uploadFile(of: upload))
            return pendingUploads().allSatisfy { $0.mealId != upload.mealId }
        case .abandoned:
            try? FileManager.default.removeItem(at: uploadFile(of: upload))
            return false
        case .retryLater:
            return false
        }
    }

    /// 画面に出す写真のファイル。元の大きさの写真があればそれ、無ければ取りに行った縮小版を返す。
    /// どちらも無い端末では、縮小版を取りに行って置く。取りに行けなければ nil
    public func photoFile(mealId: UUID, photoId: UUID) async -> URL? {
        let upload = MealPhotoUpload(mealId: mealId, photoId: photoId)
        let original = originalFile(of: upload)
        if Self.exists(original) {
            return original
        }
        let fetched = fetchedFile(of: upload)
        if Self.exists(fetched) {
            return fetched
        }
        if let fetching = fetches[upload] {
            return await fetching.value
        }
        let fetching = Task { await fetch(upload) }
        fetches[upload] = fetching
        let file = await fetching.value
        fetches[upload] = nil
        return file
    }

    public func cancelUploads() async {
        await uploader.cancelAllUploads()
    }

    public func cancelAndDeleteAll() async throws {
        await uploader.cancelAllUploads()
        for folder in [folders.originals, folders.uploads, folders.fetched]
        where Self.exists(folder) {
            try FileManager.default.removeItem(at: folder)
        }
    }

    private let folders: Folders
    private let uploader: any MealPhotoUploader
    private let downscale: @Sendable (Data) throws -> Data
    private let client: NuToriAPIClient
    private let errorReporting: any ErrorReportingSession
    private var fetches: [MealPhotoUpload: Task<URL?, Never>] = [:]
    /// 取りに行っているあいだに消した食事の縮小版を、置かないため
    private var discardedMealIds: Set<UUID> = []

    private enum UploadOutcome {
        /// サーバーが受け取った。送り残しから外す
        case delivered
        /// 送り直しても受け取られない。送り残しから外す
        case abandoned
        /// 送り残しに残し、次に開いたときに送り直す
        case retryLater

        init(_ result: MealPhotoUploadResult) {
            switch result {
            case .responded(let statusCode) where (200..<300).contains(statusCode):
                self = .delivered
            // 経路の形が違う・大きすぎる・JPEG でない
            case .responded(400), .responded(413), .responded(415):
                self = .abandoned
            case .responded, .failed:
                self = .retryLater
            }
        }
    }

    /// セッション切れと回数の歯止めは、送り直せば届くので送らない。締め出し（426）は想定した結果で、更新した版が送り直すので送らない。
    /// つながらない・時間切れ・取り消しも送らない
    private static func reportedFailure(of result: MealPhotoUploadResult) -> HandledFailure? {
        switch result {
        case .responded(let statusCode) where (200..<300).contains(statusCode):
            return nil
        case .responded(401), .responded(426), .responded(429):
            return nil
        case .responded:
            return .photoUpload
        case .failed(let error):
            if error.isCancelledTransfer {
                return nil
            }
            return HandledFailure.reported(error, as: .photoUpload)
        }
    }

    private static func exists(_ file: URL) -> Bool {
        FileManager.default.fileExists(atPath: file.path(percentEncoded: false))
    }

    private func startUpload(_ upload: MealPhotoUpload) async {
        let request = await client.mealPhotoUploadRequest(photoId: upload.photoId)
        await uploader.startUpload(upload, file: uploadFile(of: upload), request: request)
    }

    private func fetch(_ upload: MealPhotoUpload) async -> URL? {
        guard case .photo(let photo)? = try? await client.fetchMealPhoto(id: upload.photoId),
            !discardedMealIds.contains(upload.mealId)
        else {
            return nil
        }
        let file = fetchedFile(of: upload)
        do {
            try write(photo, to: file)
        } catch {
            return nil
        }
        return file
    }

    private func pendingUploads() -> [MealPhotoUpload] {
        let manager = FileManager.default
        let mealFolders =
            (try? manager.contentsOfDirectory(
                at: folders.uploads, includingPropertiesForKeys: nil)) ?? []
        return mealFolders.flatMap { mealFolder -> [MealPhotoUpload] in
            guard let mealId = UUID(uuidString: mealFolder.lastPathComponent) else { return [] }
            let files =
                (try? manager.contentsOfDirectory(at: mealFolder, includingPropertiesForKeys: nil))
                ?? []
            return files.compactMap { file in
                UUID(uuidString: file.deletingPathExtension().lastPathComponent).map {
                    MealPhotoUpload(mealId: mealId, photoId: $0)
                }
            }
        }
    }

    private func write(_ data: Data, to file: URL) throws {
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
    }

    private func removeFolders(ofMeal mealId: UUID) {
        for folder in [folders.originals, folders.uploads, folders.fetched] {
            try? FileManager.default.removeItem(at: folder.appending(path: mealId.uuidString))
        }
    }

    /// 元の写真は、撮った・選んだときの形式（JPEG・HEIC）のまま置くので、拡張子を付けない
    private func originalFile(of upload: MealPhotoUpload) -> URL {
        folders.originals.appending(
            path: "\(upload.mealId.uuidString)/\(upload.photoId.uuidString)")
    }

    private func uploadFile(of upload: MealPhotoUpload) -> URL {
        folders.uploads.appending(
            path: "\(upload.mealId.uuidString)/\(upload.photoId.uuidString).jpg")
    }

    private func fetchedFile(of upload: MealPhotoUpload) -> URL {
        folders.fetched.appending(
            path: "\(upload.mealId.uuidString)/\(upload.photoId.uuidString).jpg")
    }
}
