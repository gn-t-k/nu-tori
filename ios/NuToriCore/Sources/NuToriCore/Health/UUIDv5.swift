import Foundation

enum UUIDv5 {
    static func make(namespace: UUID, name: String) -> UUID {
        var digest = sha1(namespace.bytes + Array(name.utf8))
        digest[6] = (digest[6] & 0x0F) | 0x50
        digest[8] = (digest[8] & 0x3F) | 0x80
        return UUID(
            uuid: (
                digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6],
                digest[7], digest[8], digest[9], digest[10], digest[11], digest[12], digest[13],
                digest[14], digest[15]
            )
        )
    }

    // Foundation に SHA-1 が無い（CryptoKit は Linux で使えない）ので、UUID v5 に要る分だけ自前で持つ
    private static func sha1(_ message: [UInt8]) -> [UInt8] {
        var hash: [UInt32] = [0x6745_2301, 0xEFCD_AB89, 0x98BA_DCFE, 0x1032_5476, 0xC3D2_E1F0]
        var padded = message + [0x80]
        while padded.count % 64 != 56 {
            padded.append(0)
        }
        let bitLength = UInt64(message.count) * 8
        padded += (0..<8).map { UInt8(truncatingIfNeeded: bitLength >> UInt64(56 - $0 * 8)) }

        for blockStart in stride(from: 0, to: padded.count, by: 64) {
            var words = [UInt32](repeating: 0, count: 80)
            for index in 0..<16 {
                let offset = blockStart + index * 4
                words[index] = padded[offset..<offset + 4].reduce(0) { $0 << 8 | UInt32($1) }
            }
            for index in 16..<80 {
                let mixed =
                    words[index - 3] ^ words[index - 8] ^ words[index - 14] ^ words[index - 16]
                words[index] = mixed << 1 | mixed >> 31
            }
            var (a, b, c, d, e) = (hash[0], hash[1], hash[2], hash[3], hash[4])
            for index in 0..<80 {
                let (mix, constant): (UInt32, UInt32) =
                    switch index {
                    case 0..<20: ((b & c) | (~b & d), 0x5A82_7999)
                    case 20..<40: (b ^ c ^ d, 0x6ED9_EBA1)
                    case 40..<60: ((b & c) | (b & d) | (c & d), 0x8F1B_BCDC)
                    default: (b ^ c ^ d, 0xCA62_C1D6)
                    }
                let rotated = a << 5 | a >> 27
                let next = rotated &+ mix &+ e &+ constant &+ words[index]
                (a, b, c, d, e) = (next, a, b << 30 | b >> 2, c, d)
            }
            hash[0] = hash[0] &+ a
            hash[1] = hash[1] &+ b
            hash[2] = hash[2] &+ c
            hash[3] = hash[3] &+ d
            hash[4] = hash[4] &+ e
        }
        return hash.flatMap { word in
            (0..<4).map { UInt8(truncatingIfNeeded: word >> UInt32(24 - $0 * 8)) }
        }
    }
}

extension UUID {
    fileprivate var bytes: [UInt8] {
        withUnsafeBytes(of: uuid) { Array($0) }
    }
}
