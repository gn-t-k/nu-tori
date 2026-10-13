import Foundation
import NuToriCore
import Testing

@Suite("メモリの、1件だけの記録のキャッシュ")
struct MemorySingleRecordCacheTests {
    @Suite("まだ何も書いていないとき")
    struct Empty {
        let cache: any SingleRecordCache<AccountSettings> = MemorySingleRecordCache()

        @Test("読むと無いこと")
        func readsNothing() throws {
            #expect(try cache.read() == nil)
        }
    }

    @Suite("値を書いたとき")
    struct Written {
        let cache: any SingleRecordCache<AccountSettings> = MemorySingleRecordCache()
        let first = AccountSettings(id: UUID(), sendsUsageData: true)

        init() throws {
            try cache.write(first)
        }

        @Test("書いた値を読めること")
        func readsWritten() throws {
            #expect(try cache.read() == first)
        }

        @Suite("もう一度書くとき")
        struct WritingAgain {
            let cache: any SingleRecordCache<AccountSettings> = MemorySingleRecordCache()
            let second = AccountSettings(id: UUID(), sendsUsageData: false)

            init() throws {
                try cache.write(AccountSettings(id: UUID(), sendsUsageData: true))
            }

            @Test("値が替わること")
            func replaces() throws {
                try cache.write(second)

                #expect(try cache.read() == second)
            }
        }

        @Test("空にすると、読んでも無いこと")
        func clears() throws {
            try cache.clear()

            #expect(try cache.read() == nil)
        }
    }
}
