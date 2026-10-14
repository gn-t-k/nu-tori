import NuToriAPI
import NuToriCore
import SwiftUI

/// 足りない値のページ。ヘルスケアから取れなかった値だけを値の欄にする（身長、生まれた年、性別、活動量の3択、体重の記録が無ければ今の体重）。
/// そろうまで・受け付ける範囲の外のあいだは「次へ」を押せない。生まれた年は選べる年だけを並べる
struct GoalSetupMissingValuesPage: View {
    let content: GoalSetupFlowContent
    let actions: GoalSetupFlowActions

    var body: some View {
        if let values = content.missingValues {
            VStack(alignment: .leading, spacing: 12) {
                Text("1日の目安の計算に使う値を入れてください")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(values.asked, id: \.self) { field in
                    fieldView(field, values: values)
                }
                GoalSetupFooter(page: content.page, goBack: actions.goBack) {
                    Button("次へ", action: actions.proceedFromMissingValues)
                        .buttonStyle(.borderedProminent)
                        .disabled(!values.isComplete)
                        .accessibilityIdentifier("goal-setup-next")
                }
            }
        }
    }

    @ViewBuilder
    private func fieldView(_ field: GoalSetupMissingValues.Field, values: GoalSetupMissingValues)
        -> some View
    {
        let entry = values.entry
        switch field {
        case .height:
            numberRow(
                "身長", unit: "cm", placeholder: "170",
                value: binding(entry.heightCentimeters) { entry.with(heightCentimeters: $0) },
                identifier: "goal-setup-height")
        case .birthYear:
            LabeledContent("生まれた年") {
                Picker(
                    "生まれた年",
                    selection: binding(entry.birthYear) { entry.with(birthYear: $0) }
                ) {
                    Text("選ぶ").tag(Int?.none)
                    ForEach(values.selectableBirthYears.reversed(), id: \.self) { year in
                        // 年は桁区切りを付けない
                        Text(verbatim: "\(year)年").tag(Int?.some(year))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .accessibilityIdentifier("goal-setup-birth-year")
        case .sex:
            LabeledContent("性別") {
                Picker("性別", selection: binding(entry.sex) { entry.with(sex: $0) }) {
                    Text("男性").tag(GoalSetupBody.Sex?.some(.male))
                    Text("女性").tag(GoalSetupBody.Sex?.some(.female))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .accessibilityIdentifier("goal-setup-sex")
        case .activityLevel:
            VStack(alignment: .leading, spacing: 8) {
                Text("活動量")
                ForEach(GoalSetupBody.Level.allCases, id: \.self) { level in
                    activityRow(level, selected: entry.activityLevel == level) {
                        enter(entry.with(activityLevel: level))
                    }
                }
            }
        case .currentWeight:
            numberRow(
                "今の体重", unit: "kg", placeholder: "65.0",
                value: binding(entry.currentWeightKilograms) {
                    entry.with(currentWeightKilograms: $0)
                },
                identifier: "goal-setup-current-weight")
        }
    }

    private func numberRow(
        _ label: String, unit: String, placeholder: String, value: Binding<Double?>,
        identifier: String
    ) -> some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                TextField(placeholder, value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(minWidth: 64)
                    .fixedSize()
                    .accessibilityLabel(label)
                Text(unit)
                    .foregroundStyle(.secondary)
            }
            // DESIGN.md の value-field（Fill の地、角丸 10、内側 12）
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityIdentifier(identifier)
    }

    private func activityRow(
        _ level: GoalSetupBody.Level, selected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(level.name)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("goal-setup-activity")
    }

    private func binding<Value>(
        _ value: Value, entering: @escaping (Value) -> GoalSetupMissingValues.Entry
    ) -> Binding<Value> {
        Binding(get: { value }, set: { enter(entering($0)) })
    }

    private func enter(_ entry: GoalSetupMissingValues.Entry) {
        actions.enterMissingValues(entry)
    }
}

extension GoalSetupBody.Level {
    fileprivate var name: String {
        switch self {
        case .sedentary: "ほぼ座り仕事"
        case .standing: "立ち仕事が多い"
        case .active: "よく動く"
        }
    }
}

extension GoalSetupMissingValues.Entry {
    fileprivate func with(heightCentimeters: Double?) -> Self {
        Self(
            heightCentimeters: heightCentimeters, birthYear: birthYear, sex: sex,
            activityLevel: activityLevel, currentWeightKilograms: currentWeightKilograms)
    }

    fileprivate func with(birthYear: Int?) -> Self {
        Self(
            heightCentimeters: heightCentimeters, birthYear: birthYear, sex: sex,
            activityLevel: activityLevel, currentWeightKilograms: currentWeightKilograms)
    }

    fileprivate func with(sex: GoalSetupBody.Sex?) -> Self {
        Self(
            heightCentimeters: heightCentimeters, birthYear: birthYear, sex: sex,
            activityLevel: activityLevel, currentWeightKilograms: currentWeightKilograms)
    }

    fileprivate func with(activityLevel: GoalSetupBody.Level?) -> Self {
        Self(
            heightCentimeters: heightCentimeters, birthYear: birthYear, sex: sex,
            activityLevel: activityLevel, currentWeightKilograms: currentWeightKilograms)
    }

    fileprivate func with(currentWeightKilograms: Double?) -> Self {
        Self(
            heightCentimeters: heightCentimeters, birthYear: birthYear, sex: sex,
            activityLevel: activityLevel, currentWeightKilograms: currentWeightKilograms)
    }
}
