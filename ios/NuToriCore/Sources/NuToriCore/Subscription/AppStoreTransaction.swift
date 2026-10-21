/// StoreKit の取引。署名を確かめるのはサーバーなので、確かめられなかった取引もそのまま持つ
public struct AppStoreTransaction: Sendable, Hashable {
    /// 取引の ID。更新のたびに新しい ID の取引が来る
    public let id: UInt64
    /// `jwsRepresentation`
    public let signedTransaction: String

    public init(id: UInt64, signedTransaction: String) {
        self.id = id
        self.signedTransaction = signedTransaction
    }
}
