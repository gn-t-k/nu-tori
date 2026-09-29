import Foundation

/// 元のサンプルが消えたという書き込みを送った要求の本文を、型で読み戻して比べるためのもの
struct SentSourceDeletedWritesBody: Decodable, Equatable {
    let writes: [Write]

    init(json: String) throws {
        self = try JSONDecoder().decode(Self.self, from: Data(json.utf8))
    }

    struct Write: Decodable, Equatable {
        let id: String
        let type: String
        let weightRecordId: String
    }
}
