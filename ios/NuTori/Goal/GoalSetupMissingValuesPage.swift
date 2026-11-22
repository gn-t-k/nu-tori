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

    /// 出しているホイールのシートと、回しているあいだの位置。回すと選択が変わるので、「完了」まで流れに渡さない
    @State private var openWheel: OpenWheel?

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

    /// 出しているホイールのシートと、回しているあいだの位置
    private enum OpenWheel: Identifiable {
        case height(centimeters: Int)
        case birthYear(Int)
        /// 0.1 kg を1とした値
        case currentWeight(tenths: Int)

        /// 回しても同じシートのまま描き直すよう、どの値のホイールかだけで見分ける
        var id: GoalSetupMissingValues.Field {
            switch self {
            case .height: .height
            case .birthYear: .birthYear
            case .currentWeight: .currentWeight
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
            openWheel = .height(
                centimeters: entry.heightCentimeters.map { Int($0.rounded()) }
                    ?? GoalSetupMissingValues.initialHeightCentimeters)
        }
    }

    private func birthYearRow(_ values: GoalSetupMissingValues) -> some View {
        GoalSetupWheelRow(
            label: "生まれた年", value: values.entry.birthYear.map(Self.yearText),
            identifier: "goal-setup-birth-year"
        ) {
            openWheel = .birthYear(values.entry.birthYear ?? values.initialBirthYear)
        }
    }

    private func currentWeightRow(_ entry: GoalSetupMissingValues.Entry) -> some View {
        GoalSetupWheelRow(
            label: "今の体重", value: entry.currentWeightKilograms.map(WeightAmountText.kilograms),
            identifier: "goal-setup-current-weight"
        ) {
            openWheel = .currentWeight(
                tenths: GoalSetupMissingValues.weightTenths(
                    kilograms: entry.currentWeightKilograms
                        ?? GoalSetupMissingValues.initialWeightKilograms))
        }
    }

    @ViewBuilder
    private func wheelSheet(_ wheel: OpenWheel, values: GoalSetupMissingValues) -> some View {
        let entry = values.entry
        switch wheel {
        case .height(let centimeters):
            GoalSetupWheelSheet(
                title: "身長",
                confirm: { enter(entry.with(heightCentimeters: Double(centimeters))) },
                wheels: {
                    GoalSetupWheel(
                        "身長",
                        selection: Binding(
                            get: { centimeters }, set: { openWheel = .height(centimeters: $0) }),
                        identifier: "goal-setup-height-wheel"
                    ) {
                        ForEach(GoalSetupMissingValues.heightChoices, id: \.self) { height in
                            Text(verbatim: "\(height) cm").tag(height)
                        }
                    }
                })
        case .birthYear(let year):
            GoalSetupWheelSheet(
                title: "生まれた年", confirm: { enter(entry.with(birthYear: year)) },
                wheels: {
                    GoalSetupWheel(
                        "生まれた年",
                        selection: Binding(get: { year }, set: { openWheel = .birthYear($0) }),
                        identifier: "goal-setup-birth-year-wheel"
                    ) {
                        // 古い年を下、新しい年を上に並べる
                        ForEach(values.selectableBirthYears.reversed(), id: \.self) { year in
                            Text(Self.yearText(year)).tag(year)
                        }
                    }
                })
        case .currentWeight(let tenths):
            GoalSetupWheelSheet(
                title: "今の体重",
                confirm: {
                    enter(
                        entry.with(
                            currentWeightKilograms: GoalSetupMissingValues.weightKilograms(
                                tenths: tenths)))
                },
                wheels: {
                    GoalSetupWheel(
                        "今の体重の整数",
                        selection: Binding(
                            get: { GoalSetupMissingValues.weightWhole(tenths: tenths) },
                            set: { whole in
                                openWheel = .currentWeight(
                                    tenths: GoalSetupMissingValues.weightTenths(
                                        whole: whole,
                                        tenth: GoalSetupMissingValues.weightTenth(tenths: tenths)))
                            }),
                        identifier: "goal-setup-current-weight-whole-wheel"
                    ) {
                        ForEach(GoalSetupMissingValues.weightWholeChoices, id: \.self) { whole in
                            Text(verbatim: "\(whole)").tag(whole)
                        }
                    }
                    GoalSetupWheel(
                        "今の体重の小数",
                        selection: Binding(
                            get: { GoalSetupMissingValues.weightTenth(tenths: tenths) },
                            set: { tenth in
                                openWheel = .currentWeight(
                                    tenths: GoalSetupMissingValues.weightTenths(
                                        whole: GoalSetupMissingValues.weightWhole(tenths: tenths),
                                        tenth: tenth))
                            }),
                        identifier: "goal-setup-current-weight-tenth-wheel"
                    ) {
                        ForEach(
                            GoalSetupMissingValues.weightTenthChoices(
                                whole: GoalSetupMissingValues.weightWhole(tenths: tenths)),
                            id: \.self
                        ) { tenth in
                            Text(verbatim: ".\(tenth) kg").tag(tenth)
                        }
                    }
                })
        }
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
