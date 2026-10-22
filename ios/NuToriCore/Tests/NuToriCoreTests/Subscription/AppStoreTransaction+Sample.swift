import NuToriCore

extension AppStoreTransaction {
    static func sample(id: UInt64) -> AppStoreTransaction {
        AppStoreTransaction(id: id, signedTransaction: "jws-\(id)")
    }
}
