import SwiftUI

/// 同意の文は、次の規約や法令のために消せない。文を変えるときは、出典を読み直してから変える
/// - Anthropic の Usage Policy
/// - Anthropic の Commercial Terms D.3
/// - App Store Review Guidelines 5.1.2(i)
/// - 個人情報保護法 28 条
/// - Apple Developer Program License Agreement 3.3.3(H)
/// - 個人情報保護委員会の Q&A 12-10
/// - 利用規約への同意（「利用規約と特商法の表記の中身を決める」#593 の解決コメント。サインインで見せた版をサーバーに送る）
struct SignInConsentCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("続ける前に")
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    """
                    記録と写真（ヘルスケアから読んだ情報を含む）は、米国の会社のサービスで保存・処理します。
                    食事の推定と返事、不具合と利用状況、それらの分析に AI を使います。
                    推定の値と返事は、確かめてから使ってください。
                    [利用規約](https://nu-tori.app/terms)と[プライバシーポリシー](https://nu-tori.app/privacy)を確かめてから、続けてください。
                    """
                )
                BulletLine(text: "利用規約: 無料体験とサブスクリプション、推定と返事の扱い、禁止すること など")
                BulletLine(
                    text:
                        "プライバシーポリシー: 集める情報と使い道、送り先の会社、米国の個人情報の法律、各社が情報を守るためにしていること など"
                )
                Text("続けると、これらに同意したことになります。")
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("consentCard")
    }
}
