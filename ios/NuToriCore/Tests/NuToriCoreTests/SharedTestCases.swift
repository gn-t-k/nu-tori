import Foundation

enum SharedTestCases {
    static func decode<TestCases: Decodable>(
        _: TestCases.Type, fromFileNamed fileName: String
    ) throws -> TestCases {
        var root = URL(filePath: #filePath)
        // ios/NuToriCore/Tests/NuToriCoreTests/SharedTestCases.swift から、リポジトリの根へ上がる
        for _ in 0..<5 {
            root.deleteLastPathComponent()
        }
        let data = try Data(contentsOf: root.appending(path: "shared/\(fileName)"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TestCases.self, from: data)
    }
}
