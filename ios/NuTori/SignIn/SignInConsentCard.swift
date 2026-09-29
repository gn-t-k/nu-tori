import SwiftUI

/// 同意の文は、次の規約や法令のために消せない。文を変えるときは、出典を読み直してから変える
/// - Anthropic の Usage Policy
/// - Anthropic の Commercial Terms D.3
/// - App Store Review Guidelines 5.1.2(i)
/// - 個人情報保護法 28 条
/// - Apple Developer Program License Agreement 3.3.3(H)
/// - 個人情報保護委員会の Q&A 12-10
struct SignInConsentCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("続ける前に")
                .font(.headline)
            Text(
                """
                記録と写真（ヘルスケアから読んだ情報を含む）は、米国の会社のサービスで保存・処理します。\
                食事の推定と返事のために AI にも送り、不具合と利用状況も送って、その分析にも AI を使います。\
                推定の値と返事は、確かめてから使ってください。\
                送り先の国の制度と各社の措置を[プライバシーポリシー](https://nu-tori.app/privacy)で確かめてから、\
                続けてください。続けると、これらに同意したことになります。
                """
            )
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
