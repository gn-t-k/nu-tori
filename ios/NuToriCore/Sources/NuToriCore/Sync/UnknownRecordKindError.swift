/// 箱が、登録簿に無い種類の変更を渡された
public struct UnknownRecordKindError: Error, Equatable {
    public let kind: String

    public init(kind: String) {
        self.kind = kind
    }
}
