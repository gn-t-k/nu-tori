import SwiftUI

struct HealthAccessScreen: View {
    var body: some View {
        List {
            Section {
                row(
                    "体重、体脂肪率",
                    "ほかのアプリで記録した体重を取り込みます。"
                )
                row(
                    "身長、生年月日、性別、歩数、摂取エネルギー",
                    "目標と1日の目安の計算に使い、保存しません。"
                )
            } header: {
                Text("読む")
                    .textCase(nil)
            }
            Section {
                row("体重", "nu-tori で記録した体重。")
                row("栄養", "エネルギー、P・F・C、ビタミン、ミネラルなど。")
            } header: {
                Text("書く")
                    .textCase(nil)
            } footer: {
                Text("変えるときは、iPhone の「設定」の「プライバシーとセキュリティ」か、ヘルスケアアプリで変えられます。")
            }
        }
        .navigationTitle("ヘルスケア")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
