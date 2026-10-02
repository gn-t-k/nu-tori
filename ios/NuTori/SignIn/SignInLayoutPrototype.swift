// PROTOTYPE: 使い捨て。main に入れない
// 問い: 大きな文字（AX 5）で入りきらないとき、サインインの画面で何を送り、何を下に残すか
// 案ごとの #Preview を RenderPreview で描いて見比べる
#if DEBUG
    import NuToriCore
    import SwiftUI

    /// A: 今の形。全体を送り、ボタンは同意の文の後ろ
    private struct VariantA: View {
        let status: SignInStatus
        var body: some View {
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
            }
            .background(Color(.systemGroupedBackground))
        }
        private var content: some View {
            VStack(spacing: 24) {
                PrototypeHeader().frame(maxHeight: .infinity)
                VStack(spacing: 12) {
                    SignInConsentCard()
                    PrototypeStatusLine(status: status)
                    AppleSignInButton { _ in }
                }
            }
            .padding()
        }
    }

    /// B: 締め出しの画面と同じ。見出しと同意の文を送り、状態とボタンを下に残す
    private struct VariantB: View {
        let status: SignInStatus
        var body: some View {
            VStack(spacing: 0) {
                ViewThatFits(in: .vertical) {
                    scrolled.frame(maxHeight: .infinity)
                    ScrollView { scrolled }
                }
                VStack(spacing: 12) {
                    PrototypeStatusLine(status: status)
                    AppleSignInButton { _ in }
                }
                .padding([.horizontal, .bottom])
            }
            .background(Color(.systemGroupedBackground))
        }
        private var scrolled: some View {
            VStack(spacing: 24) {
                PrototypeHeader().frame(maxHeight: .infinity)
                SignInConsentCard()
            }
            .padding()
        }
    }

    /// C: B と同じく下に残すうえ、大きな文字では同意の文を先に、見出しをその後ろに置く。
    /// 最初の画面で同意の文の頭とボタンが一緒に見える
    private struct VariantC: View {
        let status: SignInStatus
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        var body: some View {
            VStack(spacing: 0) {
                ViewThatFits(in: .vertical) {
                    scrolled.frame(maxHeight: .infinity)
                    ScrollView { scrolled }
                }
                VStack(spacing: 12) {
                    PrototypeStatusLine(status: status)
                    AppleSignInButton { _ in }
                }
                .padding([.horizontal, .bottom])
            }
            .background(Color(.systemGroupedBackground))
        }
        @ViewBuilder private var scrolled: some View {
            VStack(spacing: 24) {
                if dynamicTypeSize.isAccessibilitySize {
                    SignInConsentCard()
                    PrototypeHeader()
                } else {
                    PrototypeHeader().frame(maxHeight: .infinity)
                    SignInConsentCard()
                }
            }
            .padding()
        }
    }

    private struct PrototypeHeader: View {
        var body: some View {
            VStack(spacing: 8) {
                Image("AppMark")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 13))
                Text("nu-tori").font(.title2.bold())
                Text("毎朝の体重と、食事の写真だけ。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private struct PrototypeStatusLine: View {
        let status: SignInStatus
        var body: some View {
            if case .failed = status {
                Text("インターネットにつながらないため、サインインできませんでした。つながるところで、もう一度押してください。")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private enum PrototypeCase: CaseIterable {
        case aReady, bReady, cReady, aFailed, bFailed, cFailed
    }

    private struct PrototypeSwitch: View {
        let sample: PrototypeCase
        var body: some View {
            switch sample {
            case .aReady: VariantA(status: .ready)
            case .bReady: VariantB(status: .ready)
            case .cReady: VariantC(status: .ready)
            case .aFailed: VariantA(status: .failed(.unreachable))
            case .bFailed: VariantB(status: .failed(.unreachable))
            case .cFailed: VariantC(status: .failed(.unreachable))
            }
        }
    }

    #Preview("案ごと", arguments: PrototypeCase.allCases) { PrototypeSwitch(sample: $0) }
#endif
