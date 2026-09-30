/// 箱や同期の働きの登録簿に無い種類の名前を渡された
public struct UnknownRecordKindError: Error, Equatable {
    public let kind: RecordKindName

    public static func notRegistered(_ kind: RecordKindName) -> UnknownRecordKindError {
        UnknownRecordKindError(kind: kind)
    }
}
