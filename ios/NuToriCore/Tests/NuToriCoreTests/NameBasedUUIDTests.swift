import Foundation
import Testing

@testable import NuToriCore

@Suite("名前から決まる UUID v5")
struct NameBasedUUIDTests {
    @Suite("RFC 4122 の DNS の名前空間と、python.org のとき")
    struct DnsNamespace {
        let namespace: UUID

        init() throws {
            namespace = try #require(UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"))
        }

        @Test("広く知られた値 886313e1-3b8a-5372-9b90-0c9aee199e5d になること")
        func matchesKnownVector() throws {
            let expected = try #require(UUID(uuidString: "886313E1-3B8A-5372-9B90-0C9AEE199E5D"))

            #expect(NameBasedUUID.version5(namespace: namespace, name: "python.org") == expected)
        }
    }

    @Suite("SHA-1 のブロックをまたぐ長い名前のとき")
    struct LongName {
        let namespace: UUID

        init() throws {
            namespace = try #require(UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"))
        }

        @Test("Python の uuid5 と同じ値になること")
        func matchesPython() throws {
            let expected = try #require(UUID(uuidString: "04F4A8AD-6EFC-5A09-9FC1-F197C5F4BF51"))

            #expect(
                NameBasedUUID.version5(
                    namespace: namespace, name: String(repeating: "あ", count: 40))
                    == expected)
        }
    }
}
