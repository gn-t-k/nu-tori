/// 規約の版
public enum TermsVersion {
    /// サインインの画面で見せる規約の版。サーバーの `currentTermsVersion`（`server/src/terms-agreement/domain/terms-versions.ts`）と同じ文字列にする。
    /// サーバーで版を上げたら合わせる。合わないと、サーバーは知らない版として同意を書かず、次に開いたときに同意のシートで取り直す
    public static let shownAtSignIn = "1"
}
