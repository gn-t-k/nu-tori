import SwiftUI

/// タイムラインに置く、サーバーが受け付けなかった1行。灰色の Footnote で右に寄せる
struct RejectedLineText: View {
    let text: String
    let subject: Subject

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityIdentifier(subject.accessibilityIdentifier)
    }

    /// 受け付けなかった書き込みの記録の種類。UI テストが1行を見分ける識別子を決める
    enum Subject {
        case weightRecord
        case meal
        case sentText

        var accessibilityIdentifier: String {
            switch self {
            case .weightRecord: "rejected-weight-line"
            case .meal: "rejected-meal-line"
            case .sentText: "rejected-sent-text-line"
            }
        }
    }
}
