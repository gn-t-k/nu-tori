/// サーバーの種類の名前と、端末の登録簿の名前の食い違い
public struct RecordKindNameMismatch: Sendable, Equatable {
    /// サーバーにあって、端末の登録簿に無い名前
    public let onlyOnServer: Set<String>
    /// 端末の登録簿にあって、サーバーに無い名前
    public let onlyOnDevice: Set<String>

    public init(onlyOnServer: Set<String>, onlyOnDevice: Set<String>) {
        self.onlyOnServer = onlyOnServer
        self.onlyOnDevice = onlyOnDevice
    }

    public var isEmpty: Bool {
        onlyOnServer.isEmpty && onlyOnDevice.isEmpty
    }
}
