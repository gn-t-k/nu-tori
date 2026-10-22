import Foundation
import NuToriCore
import SwiftUI
import UIKit

/// 送った文章の吹き出し（DESIGN.md の own-message-bubble）と、その下につなぐ文章の食事の行と、添える1行。
/// 食事があれば吹き出しと行を1つのかたまりにし（DESIGN.md の「文章とその食事のかたまり」）、かたまりの外の右下に「会話として送り直す」を置く。
/// 応答待ちの回る印と「読んでいます…」は返事が来る場所（左の地の上）に、作れなかった・回数切れの1行と「送り直す」は右下に置く
struct SentTextBubbleView: View {
    let bubble: SentTextBubble
    /// まだ届いていない文章。吹き出しを薄く描く
    let isUndelivered: Bool
    /// 「送り直す」と「会話として送り直す」
    let regeneration: Regeneration
    /// つないだ食事のうち、まだ届いていないもの。その行を薄く描く
    let isMealUndelivered: (MealCard) -> Bool
    /// つないだ食事の行を押した。その食事の画面へ潜る
    let openMeal: (MealCard) -> Void
    /// 行に描く大きさに縮めた写真。この端末に無ければ取りに行く。取れなければ nil
    let loadPhoto: (_ mealId: UUID, _ photoId: UUID) async -> UIImage?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if bubble.meals.isEmpty {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    text
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18))
                        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 18))
                        .modifier(textMenu)
                        .undeliveredRecord(isUndelivered)
                        .accessibilityIdentifier("sent-text-bubble")
                }
                .modifier(BubbleWidth())
            } else {
                joinedMeals
                if case .available(_, let resendAsConversation) = regeneration {
                    Button("会話として送り直す", action: resendAsConversation)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("resend-as-conversation")
                }
            }
            if let rejected = bubble.rejectedLine {
                RejectedLineText(text: rejected.text, subject: .sentText)
            }
            if let line = bubble.replyLine {
                replyLine(line)
            }
        }
    }

    /// 返事を作り直す操作を出すか
    enum Regeneration {
        /// resendAsConversation は、押しても確かめず、その文章の食事がすべて消える
        case available(
            resend: (ClientUsageEvent.ReplyRegenerateReason) -> Void,
            resendAsConversation: () -> Void)
        /// サブスクリプション切れのあいだ。送り直しても返事を作らずに止まり、会話として送り直すと食事だけが消えるので出さない
        case unavailable
    }

    /// 長押しのメニューで「テキストを選択」を選んでから、選び終えるまで
    @State private var isSelecting = false

    private var textMenu: MessageTextMenu {
        MessageTextMenu(
            copyText: { bubble.sentText.body }, isEnabled: true, isSelecting: $isSelecting)
    }

    private var text: some View {
        Group {
            if isSelecting {
                // 地が Primary なので、選んだ範囲とつまみは白で描く
                SelectableText(text: .sentText(bubble.sentText.body), tint: .white) {
                    isSelecting = false
                }
            } else {
                Text(bubble.sentText.body)
                    // 会話の文字は Body（自分の吹き出しも返事も）。仕様 #419「少しずつ伸びる返事」
                    .font(.body)
                    .foregroundStyle(.white)
            }
        }
        // DESIGN.md の Layout は余白を標準に任せるが、吹き出しの内側は own-message-bubble の padding（12）にそろえる（標準の .padding() は 16）
        .padding(12)
    }

    /// 吹き出しの下に食事の行をすき間なくつなぎ、外側を角丸 18 の1つのかたまりにする。幅は文章の長さによらず最大の幅
    private var joinedMeals: some View {
        VStack(alignment: .leading, spacing: 0) {
            text
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor)
                .modifier(textMenu)
                .undeliveredRecord(isUndelivered)
                .accessibilityIdentifier("sent-text-bubble")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(bubble.meals.enumerated()), id: \.element.meal.id) { index, card in
                    if index > 0 {
                        // 行の文字の左端（MealCardView の標準の余白）にそろえて、線を左から下げる
                        Divider()
                            .padding(.leading)
                    }
                    mealRow(card)
                }
            }
            .background(Color.accentColor.opacity(OwnRecordCard.tintOpacity))
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .modifier(BubbleWidth())
    }

    /// 文章の食事の行。写真の場所を持たず、文章の食事と分かる手がかりは上の吹き出し
    private func mealRow(_ card: MealCard) -> some View {
        Button {
            openMeal(card)
        } label: {
            MealCardView(card: card) { photoId in
                await loadPhoto(card.meal.id, photoId)
            }
            // 行の地はかたまりの側に付くので、地の無いラベルは文字のところしか押せない。› と余白も押せるよう、ラベルの全体を押せる形にする
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .undeliveredRecord(isMealUndelivered(card))
        .accessibilityIdentifier("meal-card")
    }

    @ViewBuilder private func replyLine(_ line: SentTextBubble.ReplyLine) -> some View {
        switch line {
        case .reading:
            // 送った文章の応答待ちの待っている表示。食事とも会話とも取れる文言にする
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(line.text)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("reply-reading")
        case .halted, .failed:
            // 添える理由は Core の resendReason の1か所で決める（この2つの場合はいつもある）
            if let reason = line.resendReason, case .available(let resend, _) = regeneration {
                resendLine(line.text) { resend(reason) }
            } else {
                failedLineText(line.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func resendLine(_ text: String, resend: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            failedLineText(text)
            Button("送り直す", action: resend)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityIdentifier("reply-resend")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func failedLineText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            .accessibilityIdentifier("reply-failed-line")
    }
}

/// 吹き出しの最大の幅（画面の 78%）で、右に寄せる
private struct BubbleWidth: ViewModifier {
    func body(content: Content) -> some View {
        content
            .containerRelativeFrame(.horizontal) { width, _ in
                let widthRatio: CGFloat = 0.78
                return width * widthRatio
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
