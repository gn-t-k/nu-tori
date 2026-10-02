import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport

extension MealPhotos {
    /// テストごとに空の一時フォルダを置き場にする。縮小版は、元の写真の前に印を付けたバイトにする
    static func fixture(
        folders: Folders = .temporary(),
        uploader: MealPhotoUploaderMock = .ok(),
        transport: ClientTransportMock = .mealPhotos([:]),
        errorReporting: ErrorReportingSessionMock = .ok()
    ) -> MealPhotos {
        MealPhotos(
            folders: folders,
            uploader: uploader,
            downscale: { Data("縮小版:".utf8) + $0 },
            client: NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: transport,
                appBuild: 1,
                sessionToken: { "session-1" },
                appBuildVerdict: { _ in }
            ),
            errorReporting: errorReporting
        )
    }

    static func downscaled(_ original: Data) -> Data {
        Data("縮小版:".utf8) + original
    }
}

extension MealPhotos.Folders {
    static func temporary() -> MealPhotos.Folders {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "NuToriCoreTests-\(UUID().uuidString)")
        return MealPhotos.Folders(
            originals: root.appending(path: "originals"),
            uploads: root.appending(path: "uploads"),
            fetched: root.appending(path: "fetched")
        )
    }
}
