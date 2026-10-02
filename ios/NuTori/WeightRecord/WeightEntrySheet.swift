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
                onBeginTyping: { detent = .large }
            )
            // タイムラインの体重の知らせにも同じステッパーがあるので、UI テストはシートの中を探す
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("weight-entry-sheet")
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(draft.tenths != draft.initialTenths)
        .onAppear {
            if draft.startsWithKeyboard {
                typing = true
            }
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
    @State private var detent: PresentationDetent
    @FocusState private var typing: Bool
    @Environment(\.dismiss) private var dismiss
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
        let draft = WeightDraft(entry)
        _entry = State(initialValue: entry)
        _draft = State(initialValue: draft)
        _observation = State(
            initialValue: WeightEntryObservation(
                startsWithKeyboard: draft.startsWithKeyboard, openedAt: now()))
        _detent = State(initialValue: draft.startsWithKeyboard ? .large : .medium)
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
        onRecord(entry.write(recording: kilograms, at: recordedAt, in: .current))
        Task { await capture(event) }
    }
}
