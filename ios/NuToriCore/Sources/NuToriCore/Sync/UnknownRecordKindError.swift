/// 登録簿に無い種類の名前を渡された
public enum UnknownRecordKindError: Error, Equatable {
    /// 箱や同期の働きの登録簿に無い
    case notRegistered(RecordKindName)
}
