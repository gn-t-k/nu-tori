/// UUID v5 を Linux でも同じに出すための SHA-1（CryptoKit は Apple の環境にしか無い）。名前から ID を決めるのにだけ使う
enum SHA1 {
    static func digest(of message: [UInt8]) -> [UInt8] {
        var state: [UInt32] = [0x6745_2301, 0xEFCD_AB89, 0x98BA_DCFE, 0x1032_5476, 0xC3D2_E1F0]
        for block in paddedBlocks(of: message) {
            state = compress(block: block, into: state)
        }
        return state.flatMap { word in
            (0..<4).map { UInt8(truncatingIfNeeded: word >> (24 - 8 * $0)) }
        }
    }

    private static func paddedBlocks(of message: [UInt8]) -> [ArraySlice<UInt8>] {
        var padded = message + [0x80]
        while padded.count % 64 != 56 {
            padded.append(0)
        }
        let bitLength = UInt64(message.count) * 8
        padded += (0..<8).map { UInt8(truncatingIfNeeded: bitLength >> (56 - 8 * UInt64($0))) }
        return stride(from: 0, to: padded.count, by: 64).map { padded[$0..<$0 + 64] }
    }

    private static func compress(block: ArraySlice<UInt8>, into state: [UInt32]) -> [UInt32] {
        let bytes = Array(block)
        var schedule = (0..<16).map { index in
            (0..<4).reduce(UInt32(0)) { $0 << 8 | UInt32(bytes[4 * index + $1]) }
        }
        for index in 16..<80 {
            let mixed =
                schedule[index - 3] ^ schedule[index - 8] ^ schedule[index - 14]
                ^ schedule[index - 16]
            schedule.append(mixed << 1 | mixed >> 31)
        }
        var working = state
        for index in 0..<80 {
            let (mixing, constant) = roundFunction(round: index, working)
            let rotatedFirst = working[0] << 5 | working[0] >> 27
            let next = rotatedFirst &+ mixing &+ working[4] &+ constant &+ schedule[index]
            working = [
                next, working[0], working[1] << 30 | working[1] >> 2, working[2], working[3],
            ]
        }
        return zip(state, working).map { $0 &+ $1 }
    }

    private static func roundFunction(round: Int, _ words: [UInt32]) -> (UInt32, UInt32) {
        let (second, third, fourth) = (words[1], words[2], words[3])
        switch round {
        case 0..<20: return ((second & third) | (~second & fourth), 0x5A82_7999)
        case 20..<40: return (second ^ third ^ fourth, 0x6ED9_EBA1)
        case 40..<60: return ((second & third) | (second & fourth) | (third & fourth), 0x8F1B_BCDC)
        default: return (second ^ third ^ fourth, 0xCA62_C1D6)
        }
    }
}
