import Crypto
import Foundation

/// 名前から決まる UUID v5（RFC 4122）。同じ名前空間と名前なら、どの端末でも同じ値になる
enum NameBasedUUID {
    static func version5(namespace: UUID, name: String) -> UUID {
        let namespaceBytes = withUnsafeBytes(of: namespace.uuid) { Array($0) }
        // UUID v5 は SHA-1 と決まっている。Apple では CryptoKit、それ以外では swift-crypto の実装になる
        var hash = Array(Insecure.SHA1.hash(data: Data(namespaceBytes + Array(name.utf8))))
        hash[6] = hash[6] & 0x0F | 0x50
        hash[8] = hash[8] & 0x3F | 0x80
        return UUID(
            uuid: (
                hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
                hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]
            )
        )
    }
}
