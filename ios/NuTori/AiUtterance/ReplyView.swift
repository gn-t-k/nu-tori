import Foundation
import NuToriCore
import SwiftUI
import UIKit

/// 返ってきた発言（DESIGN.md の reply-message）。吹き出しにせず、左の地の上に文で置き、下に指し示す食事の行を返った順に並べる。
/// 見守る要求で伸びている返事は、文字ずつ滑らかに出す。届いた返事に置き換わっても、出し終えるまで続ける
struct ReplyView: View {
    let reply: TimelineReply
    let openMeal: (MealCard) -> Void
    /// 行に描く大きさに縮めた写真。この端末に無ければ取りに行く。取れなければ nil
    let loadPhoto: (_ mealId: UUID, _ photoId: UUID) async -> UIImage?

    init(
        reply: TimelineReply,
        openMeal: @escaping (MealCard) -> Void,
        loadPhoto: @escaping (_ mealId: UUID, _ photoId: UUID) async -> UIImage?
    ) {
        self.reply = reply
        self.openMeal = openMeal
        self.loadPhoto = loadPhoto
        // 開いたときにもう届いていた返事は、伸ばさずに全部を出す
        _shownCount = State(initialValue: reply.isGrowing ? 0 : nil)
    }

    var body: some View {
        VStack(alignment: .leading) {
            if isSelecting {
                SelectableText(text: .reply(ReplyText(reply.body)), tint: nil) {
                    isSelecting = false
                }
            } else {
                replyText
                    // 行の右の余白や行のあいだを長押ししても、メニューを出す
                    .contentShape(Rectangle())
                    .modifier(
                        MessageTextMenu(
                            copyText: { ReplyText(reply.body).plainText }, isEnabled: !isRevealing,
                            isSelecting: $isSelecting))
            }
            ForEach(Array(reply.referencedMeals.enumerated()), id: \.offset) { _, card in
                ReferencedMealRow(card: card, open: openMeal, loadPhoto: loadPhoto)
            }
        }
        .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in
            let widthRatio: CGFloat = 0.92
            return width * widthRatio
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: reply.body) {
            await reveal()
        }
    }

    /// 出した文字の数。nil なら全部を出す
    @State private var shownCount: Int?
    /// 長押しのメニューで「テキストを選択」を選んでから、選び終えるまで
    @State private var isSelecting = false

    /// 伸びているか、届いた分を出し終えていないあいだ。長押しのメニューは、全部を出してから出す
    private var isRevealing: Bool {
        reply.isGrowing || shownCount.map { $0 < reply.body.count } ?? false
    }

    private var replyText: some View {
        ReplyTextView(
            text: ReplyText(String(reply.body.prefix(shownCount ?? reply.body.count)))
        )
        // VoiceOver では、伸びている途中でも届いた分を読む
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reply.body)
        .accessibilityIdentifier("reply")
    }

    /// 届いた分まで、少しずつ出す数を増やす。遅れているほど1回に多く出し、届く速さに追いつく
    private func reveal() async {
        while let shown = shownCount, shown < reply.body.count {
            do {
                try await Task.sleep(for: .milliseconds(30))
            } catch {
                return
            }
            let behind = reply.body.count - shown
            let catchUpSteps = 10
            shownCount = shown + max(1, behind / catchUpSteps)
        }
    }
}

/// 返事の本文を、段落・箇条書き・番号つきの箇条書き・太字で描く。会話の文字は Body
private struct ReplyTextView: View {
    let text: ReplyText

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(Array(text.lines.enumerated()), id: \.offset) { _, line in
                if let marker = line.marker {
                    item(marker: marker, runs: line.runs)
                } else {
                    Text(Self.attributed(line.runs))
                }
            }
        }
        .font(.body)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func item(marker: String, runs: [ReplyText.Run]) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(marker)
                .monospacedDigit()
            Text(Self.attributed(runs))
        }
    }

    private static func attributed(_ runs: [ReplyText.Run]) -> AttributedString {
        runs.reduce(into: AttributedString()) { text, run in
            switch run {
            case .plain(let part):
                text += AttributedString(part)
            case .bold(let part):
                var bold = AttributedString(part)
                bold.inlinePresentationIntent = .stronglyEmphasized
                text += bold
            }
        }
    }
}

/// 返事の下の、指し示す食事の小さな白い行（写真の縮小・名前・時刻・›）。押すと食事の画面へ潜る。
/// 文章の食事は写真の縮小の場所を出さない
private struct ReferencedMealRow: View {
    let card: MealCard
    let open: (MealCard) -> Void
    let loadPhoto: (_ mealId: UUID, _ photoId: UUID) async -> UIImage?

    var body: some View {
        Button {
            open(card)
        } label: {
            HStack(spacing: 12) {
                if let photoId = card.meal.photoIds.first {
                    thumbnail(mealId: card.meal.id, photoId: photoId)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.namePlace.dishNames ?? card.namePlace.statusLine ?? "食事")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Text(card.eatenTimeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            // DESIGN.md の Layout は余白を標準に任せるが、縮小（40）を入れた行を押せる高さ（44）に近づけるため、標準の .padding()（16）より詰める
            .padding(8)
            .frame(minHeight: 44)
            .background(
                Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reply-meal")
    }

    /// 縮小の大きさは文字の大きさに合わせる
    @ScaledMetric private var thumbnailSize: CGFloat = 40
    @State private var image: UIImage?

    private func thumbnail(mealId: UUID, photoId: UUID) -> some View {
        Color(.tertiarySystemFill)
            .frame(width: thumbnailSize, height: thumbnailSize)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
            .task(id: photoId) {
                image = await loadPhoto(mealId, photoId)
            }
    }
}
