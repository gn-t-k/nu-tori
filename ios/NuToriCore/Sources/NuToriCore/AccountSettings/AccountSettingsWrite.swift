/// アカウントの設定の書き込み。送り待ちの置き場には、アカウントの設定の種類の名前と、版 1 の形の JSON（`PendingWriteContent`）で入る
public enum AccountSettingsWrite: PendingWriteBody {
    /// 記録が無くても直す書き込みで送る。サーバーが無ければ作る
    case updateAccountSettings(AccountSettings)

    public var kindName: RecordKindName { AccountSettingsSyncKind.kindName }

    public var stored: PendingWriteContent {
        switch self {
        case .updateAccountSettings(let settings):
            .updateAccountSettings(id: settings.id, sendsUsageData: settings.sendsUsageData)
        }
    }

    /// 体重記録の JSON は、アカウントの設定の書き込みとして読まない
    public init?(stored: PendingWriteContent) {
        guard case .updateAccountSettings(let id, let sendsUsageData) = stored else {
            return nil
        }
        self = .updateAccountSettings(AccountSettings(id: id, sendsUsageData: sendsUsageData))
    }
}

/// アカウントの設定の送り待ち
public typealias PendingAccountSettingsWrite = Pending<AccountSettingsWrite>
