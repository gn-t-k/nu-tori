#if DEBUG
    // PROTOTYPE: 体重の知らせの見せ方を比べる使い捨てのコード。main には入れない。
    // 問い: 前の日の知らせの見出しを日付にし、答えた形をやめる（カードを消す）とどう見えるか。
    // 起動の値 PROTOTYPE_NOTICE=1 のときだけ、タイムラインの下に切り替えのバーを出す
    import NuToriCore
    import SwiftUI

    enum NoticePrototype: String, CaseIterable {
        /// 今の形。見出しはいつも「今日の体重」、答えたら「記録しました」
        case current = "A"
        /// 見出しを日付で分け、答えた知らせは出さない
        case hideAnswered = "B"
        /// 見出しを日付で分け、答えた知らせはカードをやめて薄い1行にする
        case answeredLine = "C"

        var name: String {
            switch self {
            case .current: "今の形"
            case .hideAnswered: "答えたら消す"
            case .answeredLine: "答えたら1行"
            }
        }

        static let storageKey = "prototype.notice-variant"

        static var isEnabled: Bool {
            ProcessInfo.processInfo.environment["PROTOTYPE_NOTICE"] == "1"
        }

        /// 切り替えのバーを出していないときは、今の形
        static func active(_ raw: String) -> NoticePrototype {
            isEnabled ? NoticePrototype(rawValue: raw) ?? .current : .current
        }

        /// 見出し。今の形は「今日の体重」だけ、ほかは今日でなければ日付
        func title(for card: NoticeCard, today: CalendarDay) -> String {
            guard self != .current, card.notice.targetDay != today else { return "今日の体重" }
            return "\(TimelineDayText.label(for: card.notice.targetDay))の体重"
        }
    }

    /// 答えた知らせを、カードをやめて薄い1行で残す（C）
    struct AnsweredNoticeLine: View {
        let card: NoticeCard
        let title: String

        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                Text("\(WeightAmountText.clock(card.clockTime)) \(title)の知らせ・記録済み")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
        }
    }

    /// 画面の下に浮かぶ切り替えのバー。デザインの一部ではないので、黒い錠剤の形にして見分ける
    struct NoticePrototypeSwitcher: View {
        @AppStorage(NoticePrototype.storageKey) private var raw = NoticePrototype.current.rawValue

        var body: some View {
            let all = NoticePrototype.allCases
            let current = NoticePrototype.active(raw)
            let index = all.firstIndex(of: current)!
            HStack(spacing: 16) {
                Button {
                    raw = all[(index + all.count - 1) % all.count].rawValue
                } label: {
                    Image(systemName: "chevron.left")
                }
                Text("\(current.rawValue)（\(current.name)）")
                    .monospacedDigit()
                    .frame(minWidth: 150)
                Button {
                    raw = all[(index + 1) % all.count].rawValue
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.85), in: Capsule())
            .shadow(radius: 6)
            .padding(.vertical, 6)
            .accessibilityIdentifier("prototype-switcher")
        }
    }
#endif
