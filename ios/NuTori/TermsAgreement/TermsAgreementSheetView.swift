import NuToriCore
import SwiftUI

/// 規約への同意のシートの中身。閉じられないシートに載せ、「同意して続ける」で同意を受け付けられたら、出した側が消す
struct TermsAgreementSheetView: View {
    /// progress はシートを出したときの状態。送るのは画面の中で進むので、あとから渡し直しても変わらない
    init(
        progress: Progress,
        agree: @escaping () async -> TermsAgreementPrompt.AgreeOutcome
    ) {
        _progress = State(initialValue: progress)
        self.agree = agree
    }

    let agree: () async -> TermsAgreementPrompt.AgreeOutcome

    var body: some View {
        VStack(spacing: 12) {
            // 文字を大きくして入りきらないときは、ボタンをいつも下に見せるため、説明だけを送る
            ViewThatFits(in: .vertical) {
                message
                    .frame(maxHeight: .infinity)
                ScrollView {
                    message
                }
            }
            VStack(spacing: 12) {
                if case .failed(let reason) = progress {
                    Text(failureMessage(for: reason))
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // 下に残す欄では送る側より先に縮められるので、文字を大きくしても文を途中で切らない
                        .fixedSize(horizontal: false, vertical: true)
                }
                agreeButton
            }
            .padding([.horizontal, .bottom])
        }
        .interactiveDismissDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("termsAgreementSheet")
    }

    enum Progress: Equatable {
        case ready
        /// 同意を送って、応答を待っている
        case agreeing
        /// 受け付けられなかった。押し直してもらう
        case failed(RequestFailureReason)
    }

    @State private var progress: Progress

    private var message: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("利用規約への同意のお願い")
                .font(.title2.bold())
            Text(
                PublicPages.linkedText(
                    "nu-tori を使い続けるには、[利用規約](\(PublicPages.terms))への同意が必要です。確かめてから、続けてください。"
                )
            )
            .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.horizontal, .top])
    }

    private var agreeButton: some View {
        Button {
            // 応答を待つあいだに続けて押されても、二重に送らない
            guard progress != .agreeing else { return }
            progress = .agreeing
            Task {
                switch await agree() {
                case .agreed:
                    progress = .ready
                case .notAgreed(let reason):
                    progress = .failed(reason)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if progress == .agreeing {
                    ProgressView()
                        // 既定の色は塗りと同じ Primary で見えないので、文字と同じ on-primary にする
                        .tint(.white)
                }
                Text("同意して続ける")
                    // 送れなかった1行と並ぶと、大きな文字では縦が足りずに「…」で切れる。切らずに折り返す
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier("agreeToTerms")
    }

    private func failureMessage(
        for reason: RequestFailureReason
    ) -> String {
        switch reason {
        case .unreachable:
            "インターネットにつながらないため、送れませんでした。つながるところで、もう一度押してください。"
        case .retryLater:
            "送れませんでした。しばらくしてから、もう一度押してください。"
        }
    }
}
