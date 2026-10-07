public import Foundation

extension UUID {
    /// API と DB で使う UUID の文字列（小文字の正規形。RFC 9562）。サーバーは ID を文字列のまま比べ、大文字の `uuidString` を断る
    public var canonicalString: String {
        uuidString.lowercased()
    }

    /// 小文字の正規形だけを読む。送る側の `canonicalString` を通さずに確かめ、偽の同期サーバーが本物と同じく大文字を断れるようにする
    init?(canonicalString string: String) {
        guard string == string.lowercased() else { return nil }
        self.init(uuidString: string)
    }
}
