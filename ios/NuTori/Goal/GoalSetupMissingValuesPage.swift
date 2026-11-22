import NuToriAPI
import NuToriCore
import SwiftUI

/// 足りない値のページ。ヘルスケアから取れなかった値だけを値の欄にする（身長、生まれた年、性別、活動量の3択、体重の記録が無ければ今の体重）。
/// そろうまで「次へ」を押せない。
///
/// 身長・今の体重・生まれた年は、DESIGN.md の値の欄（数の値は数字のキーボードを出す）に従わず、受け付ける値だけを並べたホイールをシートに出して選ばせる。
/// 打たせると、範囲の外の値で「次へ」が理由なく押せなくなり、テンキーが「次へ」と欄を隠したため（#1087。HIG の Entering data の "offer choices instead of requiring text entry"）
struct GoalSetupMissingValuesPage: View {
    let content: GoalSetupFlowContent
    let actions: GoalSetupFlowActions

    /// 出しているホイールのシート
    @State private var openWheel: WheelField?
    /// 回しているあいだのホイールの位置。回すと選択が変わるので、「完了」まで流れに渡さない。
    /// 開くときに入れた値か開いたときの位置に合わせる。シートは合わせる前の値で描かれることがあるので、初めから並べる値の中に置く
    @State private var heightDraft = GoalSetupMissingValues.initialHeightCentimeters
    @State private var weightWholeDraft = Int(GoalSetupMissingValues.initialWeightKilograms)
    @State private var weightTenthDraft = 0
    @State private var birthYearDraft = 0

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
            .sheet(item: $openWheel) { field in
                wheelSheet(field, values: values)
            }
        }
    }

    /// ホイールで選ぶ値。シートを出す印にする
    private enum WheelField: Identifiable {
        case height
        case birthYear
        case currentWeight

        var id: Self { self }
    }

    @ViewBuilder
    private func fieldView(_ field: GoalSetupMissingValues.Field, values: GoalSetupMissingValues)
        -> some View
    {
        let entry = values.entry
        switch field {
        case .height:
            heightRow(entry)
        case .birthYear:
            birthYearRow(values)
        case .sex:
            GoalSetupLabeledRow("性別") {
                Picker("性別", selection: binding(entry.sex) { entry.with(sex: $0) }) {
                    Text(GoalSetupBodyText.sex(.male)).tag(GoalSetupBody.Sex?.some(.male))
                    Text(GoalSetupBodyText.sex(.female)).tag(GoalSetupBody.Sex?.some(.female))
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
            currentWeightRow(entry)
        }
    }

    private func heightRow(_ entry: GoalSetupMissingValues.Entry) -> some View {
        GoalSetupWheelRow(
            label: "身長",
            value: entry.heightCentimeters.map { NutritionText.quantity($0, unit: "cm") },
            identifier: "goal-setup-height"
        ) {
            heightDraft =
                entry.heightCentimeters.map { Int($0.rounded()) }
                ?? GoalSetupMissingValues.initialHeightCentimeters
            openWheel = .height
        }
    }

    private func birthYearRow(_ values: GoalSetupMissingValues) -> some View {
        GoalSetupWheelRow(
            label: "生まれた年", value: values.entry.birthYear.map(Self.yearText),
            identifier: "goal-setup-birth-year"
        ) {
            birthYearDraft = values.entry.birthYear ?? values.initialBirthYear
            openWheel = .birthYear
        }
    }

    private func currentWeightRow(_ entry: GoalSetupMissingValues.Entry) -> some View {
        GoalSetupWheelRow(
            label: "今の体重", value: entry.currentWeightKilograms.map(WeightAmountText.kilograms),
            identifier: "goal-setup-current-weight"
        ) {
            let kilograms =
                entry.currentWeightKilograms ?? GoalSetupMissingValues.initialWeightKilograms
            let tenths = Int((kilograms * 10).rounded())
            weightWholeDraft = tenths / 10
            weightTenthDraft = tenths % 10
            openWheel = .currentWeight
        }
    }

    @ViewBuilder
    private func wheelSheet(_ field: WheelField, values: GoalSetupMissingValues) -> some View {
        let entry = values.entry
        switch field {
        case .height:
            GoalSetupWheelSheet(
                title: "身長",
                confirm: { enter(entry.with(heightCentimeters: Double(heightDraft))) },
                wheels: {
                    wheel("身長", selection: $heightDraft, identifier: "goal-setup-height-wheel") {
                        ForEach(GoalSetupMissingValues.heightChoices, id: \.self) { height in
                            Text(verbatim: "\(height) cm").tag(height)
                        }
                    }
                })
        case .birthYear:
            GoalSetupWheelSheet(
                title: "生まれた年", confirm: { enter(entry.with(birthYear: birthYearDraft)) },
                wheels: {
                    wheel(
                        "生まれた年", selection: $birthYearDraft,
                        identifier: "goal-setup-birth-year-wheel"
                    ) {
                        // 古い年を下、新しい年を上に並べる
                        ForEach(values.selectableBirthYears.reversed(), id: \.self) { year in
                            Text(Self.yearText(year)).tag(year)
                        }
                    }
                })
        case .currentWeight:
            GoalSetupWheelSheet(
                title: "今の体重",
                confirm: {
                    let tenths = weightWholeDraft * 10 + weightTenthDraft
                    enter(entry.with(currentWeightKilograms: Double(tenths) / 10))
                },
                wheels: {
                    wheel(
                        "今の体重の整数", selection: $weightWholeDraft,
                        identifier: "goal-setup-current-weight-whole-wheel"
                    ) {
                        ForEach(GoalSetupMissingValues.weightWholeChoices, id: \.self) { whole in
                            Text(verbatim: "\(whole)").tag(whole)
                        }
                    }
                    wheel(
                        "今の体重の小数", selection: $weightTenthDraft,
                        identifier: "goal-setup-current-weight-tenth-wheel"
                    ) {
                        ForEach(
                            GoalSetupMissingValues.weightTenthChoices(whole: weightWholeDraft),
                            id: \.self
                        ) { tenth in
                            Text(verbatim: ".\(tenth) kg").tag(tenth)
                        }
                    }
                    .onChange(of: weightWholeDraft) { _, whole in
                        // 300 kg に回すと、小数の位は 0 だけになる
                        let tenths = GoalSetupMissingValues.weightTenthChoices(whole: whole)
                        weightTenthDraft = min(
                            max(weightTenthDraft, tenths.lowerBound), tenths.upperBound)
                    }
                })
        }
    }

    private func wheel<Choices: View>(
        _ label: String, selection: Binding<Int>, identifier: String,
        @ViewBuilder choices: () -> Choices
    ) -> some View {
        Picker(label, selection: selection, content: choices)
            .pickerStyle(.wheel)
            .labelsHidden()
            // 2本並べたとき、互いの押せる範囲が重ならないよう、幅を分けて切る
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityIdentifier(identifier)
    }

    /// 年は桁区切りを付けない
    private static func yearText(_ year: Int) -> String {
        "\(year)年"
    }

    private func activityRow(
        _ level: GoalSetupBody.Level, selected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(GoalSetupBodyText.level(level))
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
