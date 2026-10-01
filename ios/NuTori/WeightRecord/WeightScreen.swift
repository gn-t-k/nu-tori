import NuToriCore
import SwiftUI

struct WeightScreen: View {
    let day: CalendarDay
    let records: [WeightRecord]
    let firstDay: CalendarDay
    let today: CalendarDay
    let rejectedLines: [RejectedWeightLine]
    let capture: (ClientUsageEvent) async -> Void
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
                    if let recordId = correction.editing?.recordId {
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
        .onAppear {
            Task { await capture(.screen(.weight)) }
        }
        .onDisappear {
            Task { await capture(.screen(.timeline)) }
        }
    }

    @State private var correction = Correction.notEditing
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
                    if correction.editing?.place != .dayGroup {
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
        if correction.editing?.recordId == record.id, correction.editing?.place == .dayGroup {
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
                if correction.editing?.recordId == record.id,
                    correction.editing?.place == .otherRecord
                {
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
            if correction.editing?.recordId == row.record.id,
                correction.editing?.place == .recentRecord
            {
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
        TextField("体重", text: draftText)
            .keyboardType(.decimalPad)
            .font(prominent ? .title2 : .body)
            .fontWeight(prominent ? .semibold : .regular)
            .monospacedDigit()
            .focused($focusedRecordId, equals: correction.editing?.recordId)
            .accessibilityLabel("体重の値")
            .onAppear { focusedRecordId = correction.editing?.recordId }
            .onChange(of: correction.editing?.draftText) { previous, next in
                guard let previous, let next else { return }
                let updated = correction.applyingTyped(previous: previous, next: next)
                if updated != correction {
                    correction = updated
                }
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

    private var draftText: Binding<String> {
        Binding(
            get: { correction.editing?.draftText ?? "" },
            set: { next in
                switch correction {
                case .notEditing:
                    return
                case .editing(let recordId, let place, let draftText, let replacesOnNextInput):
                    guard next != draftText else { return }
                    correction = .editing(
                        recordId: recordId,
                        place: place,
                        draftText: next,
                        replacesOnNextInput: replacesOnNextInput
                    )
                }
            }
        )
    }

    private func beginEditing(_ record: WeightRecord, place: CorrectionOrigin) {
        if let editing = correction.editing,
            editing.recordId != record.id || editing.place != place
        {
            commit(recordId: editing.recordId)
        }
        correction = .editing(
            recordId: record.id,
            place: place,
            draftText: shownNumber(record.kilograms),
            replacesOnNextInput: true
        )
        focusedRecordId = record.id
    }

    private func commit(recordId: UUID) {
        let text: String
        let place: CorrectionOrigin
        switch correction {
        case .notEditing:
            return
        case .editing(let editingRecordId, let editingPlace, let draftText, _):
            guard editingRecordId == recordId else { return }
            text = draftText
            place = editingPlace
        }
        correction = .notEditing
        guard let kilograms = kilograms(in: text),
            let record = records.first(where: { $0.id == recordId }),
            let corrected = record.correction(replacingKilograms: kilograms)
        else { return }
        Task {
            await capture(.weightCorrected(place.usagePlace))
            await saveWeight(.correct(corrected))
        }
    }

    private func kilograms(in text: String) -> Double? {
        let core = text.hasSuffix(".") ? String(text.dropLast()) : text
        guard !core.isEmpty, let value = Double(core) else { return nil }
        return value
    }
}

private enum CorrectionOrigin: Equatable {
    case dayGroup
    case otherRecord
    case recentRecord

    var usagePlace: ClientUsageEvent.WeightCorrectionPlace {
        switch self {
        case .dayGroup: .daySummary
        case .otherRecord: .otherRecords
        case .recentRecord: .recentRecords
        }
    }
}

private enum Correction: Equatable {
    case notEditing
    case editing(
        recordId: UUID,
        place: CorrectionOrigin,
        draftText: String,
        replacesOnNextInput: Bool
    )

    var editing: (recordId: UUID, place: CorrectionOrigin, draftText: String)? {
        switch self {
        case .notEditing:
            nil
        case .editing(let recordId, let place, let draftText, _):
            (recordId, place, draftText)
        }
    }

    func applyingTyped(previous: String, next: String) -> Correction {
        switch self {
        case .notEditing:
            return self
        case .editing(let recordId, let place, let draftText, let replacesOnNextInput):
            guard draftText == next else { return self }
            let raw: String
            if replacesOnNextInput {
                raw = next.count > previous.count ? Self.inserted(from: previous, to: next) : next
            } else {
                raw = next
            }
            let sanitized = WeightDecimalText.sanitized(raw)
            if !replacesOnNextInput, sanitized == draftText { return self }
            return .editing(
                recordId: recordId,
                place: place,
                draftText: sanitized,
                replacesOnNextInput: false
            )
        }
    }

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
