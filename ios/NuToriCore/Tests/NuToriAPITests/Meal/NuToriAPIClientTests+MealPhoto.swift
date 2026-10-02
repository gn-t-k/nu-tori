import Foundation
import HTTPTypes
import NuToriTestSupport
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("食事の写真")
    struct MealPhoto {
        static let photoId = "00000000-0000-4000-8000-0000000000C1"

        @Suite("縮小版を取りに行き、サーバーが写真を返したとき")
        struct Fetched {
            let photo: Data
            let transport: ClientTransportMock
            let client: NuToriAPIClient

            init() throws {
                photo = Data([0xFF, 0xD8, 0xFF, 0xD9])
                transport = .mealPhotos([try #require(UUID(uuidString: MealPhoto.photoId)): photo])
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: transport,
                    appBuildGate: .sample,
                    sessionToken: { "session-1" }
                )
            }

            @Test("写真の ID の経路を GET し、写真のバイトを返すこと")
            func returnsPhoto() async throws {
                let result = try await client.fetchMealPhoto(
                    id: try #require(UUID(uuidString: MealPhoto.photoId)))

                #expect(result == .photo(photo))
                let request = try #require(transport.requests.first).request
                #expect(request.method == .get)
                #expect(request.path == "/v1/meal-photos/\(MealPhoto.photoId)")
            }
        }

        @Suite("縮小版を取りに行き、サーバーがまだ受け取っていないか消していたとき")
        struct NotFound {
            let client: NuToriAPIClient

            init() {
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.mealPhotos([:]),
                    appBuildGate: .sample,
                    sessionToken: { "session-1" }
                )
            }

            @Test("無いと返すこと")
            func returnsNotFound() async throws {
                let result = try await client.fetchMealPhoto(id: UUID())

                #expect(result == .notFound)
            }
        }

        @Suite("縮小版を送る要求を組むとき")
        struct UploadRequest {
            let client: NuToriAPIClient

            init() {
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.mealPhotos([:]),
                    appBuildGate: AppBuildGateMock.ok(build: 42).gate,
                    sessionToken: { "session-1" }
                )
            }

            @Test("写真の ID の経路に、セッションと JPEG とビルド番号の見出しを付けて PUT すること")
            func buildsPut() async throws {
                let request = await client.mealPhotoUploadRequest(
                    photoId: try #require(UUID(uuidString: MealPhoto.photoId)))

                #expect(
                    request
                        == MealPhotoUploadRequest(
                            url: try #require(
                                URL(
                                    string:
                                        "https://api.example/v1/meal-photos/\(MealPhoto.photoId)")
                            ),
                            method: "PUT",
                            headerFields: [
                                "Authorization": "Bearer session-1",
                                "Content-Type": "image/jpeg",
                                "X-App-Build": "42",
                            ]
                        ))
            }
        }
    }
}
