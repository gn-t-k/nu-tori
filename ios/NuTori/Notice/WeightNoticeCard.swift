import NuToriCore
import SwiftUI

/// タイムラインの体重の知らせ。今日の答えていない知らせは、中で体重を記録できる
struct WeightNoticeCard: View {
    let card: NoticeCard
    /// 前回の値と、今日の手の記録を直すかを決める記録
    let records: [WeightRecord]
    let today: CalendarDay
    let now: () -> Date
    let capture: (ClientUsageEvent) async -> Void
    let onRecord: (WeightEntry.Write) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("今日の体重")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(WeightAmountText.clock(card.clockTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            switch card.form {
            case .awaitingAnswer:
                NoticeWeightEntry(
                    records: records, today: today, now: now, capture: capture,
                    onRecord: onRecord
                )
                // 値は作ったときの記録で決まる。カードが出たあとに前回の体重が届いたら（開いたときの取得、
                // ほかの端末の記録）、その値から始め直す
                .id(WeightEntry(weightRecords: records, today: today).initialValue)
            case .answered, .unansweredPastDay:
                EmptyView()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        // DESIGN.md の timeline-card。アプリからの知らせは全幅の白いカード
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weight-notice")
    }

    private var detail: String {
        switch card.form {
        case .awaitingAnswer, .unansweredPastDay: "いつもはこの時間までに記録しています。"
        case .answered: "記録しました"
        }
    }
}

/// 知らせの中のステッパーと「記録」。体重のシートと同じ値から始め、同じ書き込みを作る
private struct NoticeWeightEntry: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            WeightEntryControls(
                entry: entry,
                draft: $draft,
                observation: $observation,
                typing: $typing,
                startsTyping: false,
                onBeginTyping: {}
            )
            .frame(maxWidth: .infinity)
            Button("記録", action: record)
                .buttonStyle(.borderedProminent)
                .disabled(!canRecord)
                .accessibilityIdentifier("weight-notice-record")
        }
    }

    @State private var draft: WeightDraft
    @State private var entry: WeightEntry
    @State private var observation: WeightEntryObservation
    @FocusState private var typing: Bool
    private let now: () -> Date
    private let capture: (ClientUsageEvent) async -> Void
    private let onRecord: (WeightEntry.Write) -> Void

    init(
        records: [WeightRecord],
        today: CalendarDay,
        now: @escaping () -> Date,
        capture: @escaping (ClientUsageEvent) async -> Void,
        onRecord: @escaping (WeightEntry.Write) -> Void
    ) {
        let entry = WeightEntry(weightRecords: records, today: today)
        self.now = now
        self.capture = capture
        self.onRecord = onRecord
        _entry = State(initialValue: entry)
        _draft = State(initialValue: WeightDraft(entry))
        // カードが作られるのは、タイムラインで見えるところに来たとき
        _observation = State(initialValue: .inNotice(shownAt: now()))
    }

    private var canRecord: Bool {
        guard let kilograms = draft.kilograms else { return false }
        return entry.canRecord(kilograms)
    }

    private func record() {
        guard let kilograms = draft.kilograms else { return }
        typing = false
        let recordedAt = now()
        let event = observation.recordedEvent(at: recordedAt)
        onRecord(entry.write(recording: kilograms, at: recordedAt, in: .current))
        Task { await capture(event) }
    }
}
