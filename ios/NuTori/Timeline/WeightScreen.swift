import NuToriCore
import SwiftUI

struct WeightScreen: View {
    let day: CalendarDay
    let records: [WeightRecord]
    let firstDay: CalendarDay
    let today: CalendarDay
    let rejectedLines: [RejectedWeightLine]
    let saveWeight: (WeightEntry.Write) async -> Void

    var body: some View {
        List {
            Section {
                dayGroup
                ForEach(otherRecords, id: \.id) { record in
                    otherRecordRow(record)
                }
            } footer: {
                Text("この日の最初の記録を、この日の体重として使います。")
            }
            if !recent.sinceFirstDay.isEmpty {
                Section {
                    ForEach(recent.sinceFirstDay, id: \.record.id) { row in
                        recentRow(row)
                    }
                } header: {
                    Text("最近の記録")
                }
            }
            if !recent.beforeFirstDay.isEmpty {
                Section {
                    ForEach(recent.beforeFirstDay, id: \.record.id) { row in
                        beforeFirstDayRow(row)
                    }
                } header: {
                    Text("使い始める前（ヘルスケア）")
                } footer: {
                    Text("使い始める前の体重は、目標と1日の目安の計算に使います。")
                }
            }
        }
        .navigationTitle("体重")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("weight-screen")
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    if let recordId = editingRecordId {
                        commit(recordId: recordId)
                    }
                    focusedRecordId = nil
                }
            }
        }
        .onChange(of: focusedRecordId) { previous, current in
            guard let previous, current == nil else { return }
            commit(recordId: previous)
        }
    }

    @State private var editingRecordId: UUID?
    @State private var editingPlace: CorrectionOrigin?
    @State private var draftText = ""
    @State private var replacesOnNextInput = false
    @FocusState private var focusedRecordId: UUID?

    private var sameDayRecords: [WeightRecord] {
        records.filter { $0.day == day }.sorted { $0.instant < $1.instant }
    }

    private var otherRecords: [WeightRecord] {
        Array(sameDayRecords.dropFirst())
    }

    private var recent: RecentWeightRecords {
        RecentWeightRecords(weightRecords: records, firstDay: firstDay, today: today)
    }

    @ViewBuilder private var dayGroup: some View {
        if let representative = sameDayRecords.first {
            VStack(alignment: .leading, spacing: 4) {
                Text(TimelineDayText.label(for: day))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    dayValue(representative)
                    Spacer(minLength: 12)
                    if editingPlace != .dayGroup {
                        Button("直す") {
                            beginEditing(representative, place: .dayGroup)
                        }
                    }
                }
                Text(representative.sourceAndTimeLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                rejectionLine(for: representative.id)
            }
        } else {
            Text(TimelineDayText.label(for: day))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func dayValue(_ record: WeightRecord) -> some View {
        if editingRecordId == record.id, editingPlace == .dayGroup {
            weightField(prominent: true)
        } else {
            Button {
                beginEditing(record, place: .dayGroup)
            } label: {
                prominentKilograms(record.kilograms)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private func otherRecordRow(_ record: WeightRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.sourceAndTimeLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                if editingRecordId == record.id, editingPlace == .otherRecord {
                    weightField(prominent: false)
                } else {
                    Button {
                        beginEditing(record, place: .otherRecord)
                    } label: {
                        Text(WeightAmountText.kilograms(record.kilograms))
                            .monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            rejectionLine(for: record.id)
        }
    }

    @ViewBuilder private func recentRow(_ row: RepresentativeWeight) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if editingRecordId == row.record.id, editingPlace == .recentRecord {
                weightField(prominent: false)
            } else {
                Button {
                    beginEditing(row.record, place: .recentRecord)
                } label: {
                    HStack {
                        Text(TimelineDayText.label(for: row.day))
                        Spacer(minLength: 12)
                        Text(WeightAmountText.kilograms(row.record.kilograms))
                            .monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                        if row.otherRecordCount > 0 {
                            Text("ほか\(row.otherRecordCount)件")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            rejectionLine(for: row.record.id)
        }
    }

    private func beforeFirstDayRow(_ row: RepresentativeWeight) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(TimelineDayText.label(for: row.day))
            Text(WeightAmountText.kilograms(row.record.kilograms))
                .monospacedDigit()
            Text(sourceAppName(row.record))
                .font(.footnote)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func weightField(prominent: Bool) -> some View {
        TextField("体重", text: $draftText)
            .keyboardType(.decimalPad)
            .font(prominent ? .title2 : .body)
            .fontWeight(prominent ? .semibold : .regular)
            .monospacedDigit()
            .focused($focusedRecordId, equals: editingRecordId)
            .accessibilityLabel("体重の値")
            .onAppear { focusedRecordId = editingRecordId }
            .onChange(of: draftText) { previous, next in
                applyTyped(previous: previous, next: next)
            }
    }

    private func prominentKilograms(_ kilograms: Double) -> some View {
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(shownNumber(kilograms))
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
            Text("kg")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func rejectionLine(for recordId: UUID) -> some View {
        if let text = rejectedLines.first(where: { $0.record.id == recordId })?.text {
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func shownNumber(_ kilograms: Double) -> String {
        let tenths = Int((kilograms * 10).rounded())
        return "\(tenths / 10).\(abs(tenths) % 10)"
    }

    private func sourceAppName(_ record: WeightRecord) -> String {
        switch record.inputSource {
        case .manual:
            "手で記録"
        case .imported(let source):
            source.appName
        }
    }

    private func beginEditing(_ record: WeightRecord, place: CorrectionOrigin) {
        if let editingRecordId, editingRecordId != record.id || editingPlace != place {
            commit(recordId: editingRecordId)
        }
        draftText = shownNumber(record.kilograms)
        replacesOnNextInput = true
        editingRecordId = record.id
        editingPlace = place
        focusedRecordId = record.id
    }

    private func commit(recordId: UUID) {
        guard editingRecordId == recordId else { return }
        let text = draftText
        editingRecordId = nil
        editingPlace = nil
        guard let kilograms = kilograms(in: text),
            let record = records.first(where: { $0.id == recordId }),
            let corrected = record.correction(replacingKilograms: kilograms)
        else { return }
        Task { await saveWeight(.correct(corrected)) }
    }

    private func applyTyped(previous: String, next: String) {
        let raw: String
        if replacesOnNextInput {
            replacesOnNextInput = false
            raw = next.count > previous.count ? inserted(from: previous, to: next) : next
        } else {
            raw = next
        }
        let sanitized = WeightDecimalText.sanitized(raw)
        if draftText != sanitized {
            draftText = sanitized
        }
    }

    private func inserted(from previous: String, to next: String) -> String {
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

    private func kilograms(in text: String) -> Double? {
        let core = text.hasSuffix(".") ? String(text.dropLast()) : text
        guard !core.isEmpty, let value = Double(core) else { return nil }
        return value
    }
}

private enum CorrectionOrigin {
    case dayGroup
    case otherRecord
    case recentRecord
}
