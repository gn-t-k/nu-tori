import Foundation

@testable import NuToriAPI

/// 送り待ちを送った本文を、生成した型のまま読んだもの
///
/// エンコードのテストは、読み口（`SentSyncWrites`）で送る前の型に戻さず、これで線上の値を比べる。
/// 送ると読むが同じ取り違え（秒とミリ秒など）をしたとき、往復させると通ってしまうため
typealias PushSyncWritesPayload = Operations.PushSyncWrites.Input.Body.JsonPayload

extension PushSyncWritesPayload {
    init(sentBody: String?) throws {
        self = try JSONDecoder().decode(Self.self, from: Data((sentBody ?? "").utf8))
    }
}
