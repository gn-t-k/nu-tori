/// 閉じられない同意のシートに出すもの。告知に頼らず、仕様「告知と利用の停止」の同意の取り直しもこのシートを使う
public struct TermsAgreementSheet: Sendable, Equatable {
    /// 同意する規約の版。サーバーが同意が要ると答えた今の版
    public let termsVersion: String

    public init(termsVersion: String) {
        self.termsVersion = termsVersion
    }
}
