/// 種類の名前を扱えない（登録簿に無い、または送り待ちに入らない種類）
public enum UnknownRecordKindError: Error, Equatable {
    /// 箱や同期の働きの登録簿に無い
    case notRegistered(RecordKindName)
    /// サーバーだけが書く種類で、送る書き込みを持たない
    case serverOnly(RecordKindName)
}
