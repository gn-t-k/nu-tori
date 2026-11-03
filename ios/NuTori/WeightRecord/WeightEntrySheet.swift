import NuToriCore
import SwiftUI

struct WeightEntrySheet: View {
    var body: some View {
        NavigationStack {
            WeightEntryControls(
                entry: entry,
                draft: $draft,
                observation: $observation,
                typing: $typing,
                startsTyping: draft.startsWithKeyboard
            )
            // タイムラインの体重の知らせにも同じステッパーがあるので、UI テストはシートの中を探す
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("weight-entry-sheet")
            .padding()
            // シートが低いときに縮めて測ると、低いままになる
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { contentHeight = $0 }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onGeometryChange(for: CGFloat.self, of: \.safeAreaInsets.top) { barHeight = $0 }
            .navigationTitle("体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("記録", action: record)
                        .disabled(!canRecord)
                }
            }
        }
        // large を選べると、キーボードが出たときに iOS が large へ上げて、中身とキーボードのあいだが空く
        .presentationDetents(typing ? [fittedDetent] : [fittedDetent, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(draft.tenths != draft.initialTenths)
        .onAppear {
            Task { await capture(.screen(.weightEntry)) }
        }
        .onDisappear {
            guard !didRecord else { return }
            Task { await capture(.weightInputCancelled) }
        }
    }

    @State private var draft: WeightDraft
    @State private var entry: WeightEntry
    @State private var observation: WeightEntryObservation
    @State private var didRecord = false
    /// 測るまでの仮の値。標準の文字の中身のおおよその高さ
    @State private var contentHeight: CGFloat = 130
    /// 測るまでの仮の値。ナビゲーションバーのおおよその高さ
    @State private var barHeight: CGFloat = 60
    @FocusState private var typing: Bool
    @Environment(\.dismiss) private var dismiss
    private let now: () -> Date
    private let timeZone: () -> TimeZone
    private let capture: (ClientUsageEvent) async -> Void
    private let onRecord: (WeightEntry.Write) -> Void

    init(
        records: [WeightRecord],
        today: CalendarDay,
        now: @escaping () -> Date,
        timeZone: @escaping () -> TimeZone,
        capture: @escaping (ClientUsageEvent) async -> Void,
        onRecord: @escaping (WeightEntry.Write) -> Void
    ) {
        let entry = WeightEntry(weightRecords: records, today: today)
        self.now = now
        self.timeZone = timeZone
        self.capture = capture
        self.onRecord = onRecord
        let draft = WeightDraft(entry)
        _entry = State(initialValue: entry)
        _draft = State(initialValue: draft)
        _observation = State(
            initialValue: WeightEntryObservation(
                startsWithKeyboard: draft.startsWithKeyboard, openedAt: now()))
    }

    /// 中身が画面より高ければ、シートが画面の中で止める（縦向きの iPhone では、いちばん大きな文字でも起きない）
    private var fittedDetent: PresentationDetent {
        .height(contentHeight + barHeight)
    }

    private var canRecord: Bool {
        guard let kilograms = draft.kilograms else { return false }
        return entry.canRecord(kilograms)
    }

    private func record() {
        guard let kilograms = draft.kilograms else { return }
        didRecord = true
        let recordedAt = now()
        let event = observation.recordedEvent(at: recordedAt)
        onRecord(entry.write(recording: kilograms, at: recordedAt, in: timeZone()))
        Task { await capture(event) }
    }
}
