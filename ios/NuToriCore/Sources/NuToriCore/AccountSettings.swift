public import Foundation

/// アカウントに1つ持つ、アカウント全体にかかる設定
public struct AccountSettings: Sendable, Equatable {
    public let id: UUID
    public let sendsUsageData: Bool

    public init(id: UUID, sendsUsageData: Bool) {
        self.id = id
        self.sendsUsageData = sendsUsageData
    }

    /// 2台がそれぞれ作っても、サーバーの1件の記録に当たるよう、アカウント ID から決める
    public static func id(forAccountId accountId: String) -> UUID {
        let namespace = UUID(uuidString: "7A1020F0-70CA-4480-A4CB-870A492DE746")!
        return NameBasedUUID.version5(namespace: namespace, name: accountId)
    }
}
