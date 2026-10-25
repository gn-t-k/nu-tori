import SwiftUI

struct HealthAccessScreen: View {
    var body: some View {
        List {
            Section {
                Text("体重、体脂肪率")
                row(
                    "身長、生年月日、性別、歩数、摂取エネルギー",
                    "初めて目標を立てるときに、目標と推定消費カロリーの計算に使い、保存しません。"
                )
            } header: {
                Text("読む")
                    .textCase(nil)
            }
            Section {
                Text("体重")
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
