#if DEBUG
    // PROTOTYPE: 会話で話し手が変わるところの間を比べる使い捨てのコード（#449）。main には入れない。
    // 問い: 自分の吹き出しのすぐ下に返事（地の文）が続くとき、間をいくつにすると前の吹き出しの続きに見えないか。
    // 起動の値 PROTOTYPE_CONVERSATION_GAP=1 のときだけ、タイムラインの下に切り替えのバーを出す
    import NuToriCore
    import SwiftUI

    enum ConversationGapPrototype: String, CaseIterable {
        /// 今の形。発言が続くと、話し手によらず 8
        case current = "A"
        /// 話し手が変わるところだけ、8 と 24 のあいだの 16
        case middle = "B"
        /// 話し手が変わるところは 24。同じ話し手が続くところだけ 8
        case apart = "C"

        var name: String {
            switch self {
            case .current: "今の形・8"
            case .middle: "変わるところ 16"
            case .apart: "変わるところ 24"
            }
        }

        static let storageKey = "prototype.conversation-gap-variant"

        static var isEnabled: Bool {
            ProcessInfo.processInfo.environment["PROTOTYPE_CONVERSATION_GAP"] == "1"
        }

        /// 切り替えのバーを出していないときは、今の形
        static func active(_ raw: String) -> ConversationGapPrototype {
            isEnabled ? ConversationGapPrototype(rawValue: raw) ?? .current : .current
        }

        /// 詰める（`.close`）と決まった項目の前の間。話し手が変わるところだけを案ごとに変える
        func closeGap(before item: Timeline.Item, in day: Timeline.Day) -> CGFloat {
            guard self != .current, let index = day.items.firstIndex(of: item), index > 0,
                let speaker = Self.speaker(of: item),
                let previousSpeaker = Self.speaker(of: day.items[index - 1]),
                speaker != previousSpeaker
            else { return 8 }
            return self == .middle ? 16 : 24
        }

        private enum Speaker { case me, ai }

        private static func speaker(of item: Timeline.Item) -> Speaker? {
            switch item {
            case .sentText: .me
            case .reply: .ai
            default: nil
            }
        }
    }

    /// 画面の下に浮かぶ切り替えのバー。デザインの一部ではないので、黒い錠剤の形にして見分ける
    struct ConversationGapPrototypeSwitcher: View {
        @AppStorage(ConversationGapPrototype.storageKey) private var raw =
            ConversationGapPrototype.current.rawValue

        var body: some View {
            let all = ConversationGapPrototype.allCases
            let current = ConversationGapPrototype.active(raw)
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
