import NuToriCore
import SwiftUI

struct WeightEntrySheet: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    WeightStepButton(title: "−", label: "0.1 kg 減らす", enabled: canDecrease) {
                        draft.step(by: -1)
                        typing = false
                    }
                    value
                    WeightStepButton(title: "+", label: "0.1 kg 増やす", enabled: canIncrease) {
                        draft.step(by: 1)
                        typing = false
                    }
                }
                if let previousText {
                    Text(previousText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let typoText {
                    Text(typoText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
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
        }
    }

    @State private var draft: Draft
    @State private var entry: WeightEntry
    @State private var detent: PresentationDetent
    @FocusState private var typing: Bool
    @Environment(\.dismiss) private var dismiss
    private let onRecord: (WeightEntry.Write) -> Void

    init(records: [WeightRecord], onRecord: @escaping (WeightEntry.Write) -> Void) {
        let entry = WeightEntry(
            weightRecords: records, today: CalendarDay(containing: .now, in: .current))
        self.onRecord = onRecord
        let draft = Draft(entry)
        _entry = State(initialValue: entry)
        _draft = State(initialValue: draft)
        _detent = State(initialValue: draft.startsWithKeyboard ? .large : .medium)
    }

    @ViewBuilder private var value: some View {
        if typing {
            TextField("", text: $draft.text)
                .keyboardType(.decimalPad)
                .font(.title2)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .focused($typing)
                .frame(minWidth: 88)
                .onChange(of: draft.text) { previous, next in
                    draft.applyTyped(previous: previous, next: next)
                }
                .accessibilityLabel("体重の値")
        } else {
            Button {
                draft.beginTyping()
                typing = true
                detent = .large
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(draft.text)
                        .font(.title2)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("kg")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 88)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WeightAmountText.kilograms(kilograms ?? 0))
            .animation(.default, value: draft.tenths)
        }
    }

    private var canDecrease: Bool {
        guard let tenths = draft.tenths else { return false }
        return tenths > Draft.minimumTenths
    }

    private var canIncrease: Bool {
        guard let tenths = draft.tenths else { return false }
        return tenths < Draft.maximumTenths
    }

    private var kilograms: Double? {
        guard let tenths = draft.tenths else { return nil }
        return Double(tenths) / 10
    }

    private var canRecord: Bool {
        guard let kilograms else { return false }
        return entry.canRecord(kilograms)
    }

    private var previousText: String? {
        guard case .previous(let kilograms, let day) = entry.initialValue else { return nil }
        return "前回 \(TimelineDayText.label(for: day)) \(WeightAmountText.kilograms(kilograms))"
    }

    private var typoText: String? {
        guard let kilograms, let typo = entry.possibleTypo(for: kilograms) else { return nil }
        let direction =
            switch typo.direction {
            case .heavier: "重い"
            case .lighter: "軽い"
            }
        let day = "\(typo.previousDay.month)月\(typo.previousDay.day)日"
        let difference = WeightAmountText.kilograms(typo.differenceKilograms)
        return "前回（\(day)）より \(difference) \(direction)値です"
    }

    private func record() {
        guard let kilograms else { return }
        onRecord(entry.write(recording: kilograms, at: .now, in: .current))
    }
}

private struct Draft {
    var tenths: Int?
    var initialTenths: Int?
    var text: String
    var replacesOnNextInput: Bool
    var startsWithKeyboard: Bool

    init(_ entry: WeightEntry) {
        switch entry.initialValue {
        case .empty:
            tenths = nil
            initialTenths = nil
            text = ""
            replacesOnNextInput = false
            startsWithKeyboard = true
        case .previous(let kilograms, _):
            let tenths = Int((kilograms * 10).rounded())
            self.tenths = tenths
            initialTenths = tenths
            text = Self.decimal(tenths)
            replacesOnNextInput = false
            startsWithKeyboard = false
        }
    }

    mutating func beginTyping() {
        replacesOnNextInput = tenths != nil
    }

    mutating func applyTyped(previous: String, next: String) {
        let raw: String
        if replacesOnNextInput {
            replacesOnNextInput = false
            raw = next.count > previous.count ? Self.inserted(from: previous, to: next) : next
        } else {
            raw = next
        }
        let sanitized = WeightDecimalText.sanitized(raw)
        if text != sanitized {
            text = sanitized
        }
        tenths = Self.tenths(parsing: sanitized)
    }

    mutating func step(by delta: Int) {
        guard let tenths else { return }
        let next = tenths + delta
        if next < Self.minimumTenths && delta < 0 { return }
        if next > Self.maximumTenths && delta > 0 { return }
        replacesOnNextInput = false
        self.tenths = next
        text = Self.decimal(next)
    }

    static var minimumTenths: Int {
        Int(AcceptedRange.weightKilograms.bounds.lowerBound * 10)
    }

    static var maximumTenths: Int {
        Int(AcceptedRange.weightKilograms.bounds.upperBound * 10)
    }

    private static func decimal(_ tenths: Int) -> String {
        let absolute = abs(tenths)
        return "\(absolute / 10).\(absolute % 10)"
    }

    private static func tenths(parsing text: String) -> Int? {
        let core = text.hasSuffix(".") ? String(text.dropLast()) : text
        guard !core.isEmpty, let value = Double(core) else { return nil }
        return Int((value * 10).rounded())
    }

    /// 先頭か末尾に足した文字。選択を置き換えたときは、増えた部分だけを返す
    private static func inserted(from previous: String, to next: String) -> String {
        let previousCharacters = Array(previous)
        let nextCharacters = Array(next)
        var prefix = 0
        while prefix < previousCharacters.count && prefix < nextCharacters.count
            && previousCharacters[prefix] == nextCharacters[prefix]
        {
            prefix += 1
        }
        var suffix = 0
        while suffix < previousCharacters.count - prefix && suffix < nextCharacters.count - prefix
            && previousCharacters[previousCharacters.count - 1 - suffix]
                == nextCharacters[nextCharacters.count - 1 - suffix]
        {
            suffix += 1
        }
        return String(nextCharacters[prefix..<(nextCharacters.count - suffix)])
    }
}

private struct WeightStepButton: View {
    let title: String
    let label: String
    let enabled: Bool
    let step: () -> Void

    var body: some View {
        Button(action: stepOnce) {
            Text(title)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemFill), in: Circle())
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .onLongPressGesture(minimumDuration: 0.4, pressing: updatePress, perform: {})
        .onDisappear {
            stepTask?.cancel()
        }
    }

    @State private var stepTask: Task<Void, Never>?
    @State private var steppedFromPress = false

    private func stepOnce() {
        if steppedFromPress {
            steppedFromPress = false
            return
        }
        step()
    }

    private func updatePress(_ pressing: Bool) {
        if pressing {
            guard enabled, stepTask == nil else { return }
            steppedFromPress = true
            step()
            stepTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                while !Task.isCancelled {
                    step()
                    try? await Task.sleep(for: .milliseconds(90))
                }
            }
        } else {
            stepTask?.cancel()
            stepTask = nil
        }
    }
}
