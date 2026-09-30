/// 登録簿に無い種類、または読めない種類の名前を渡された
public enum UnknownRecordKindError: Error, Equatable {
    /// 名前は読めたが、箱や同期の働きの登録簿に無い
    case notRegistered(RecordKindName)
    /// 置き場に保存された文字列が、どの `RecordKindName` にも読めない。開くときに捨てるので通常は起きない
    case unreadableName(String)
}
