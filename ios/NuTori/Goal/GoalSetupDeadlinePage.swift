import NuToriAPI
import NuToriCore
import SwiftUI

/// 期限のページ。チップ「1か月後・2か月後・3か月後・6か月後」（6か月後が選べる最後の日を越えるときは「26週後」）と、
/// 「期限」の行の標準の DatePicker（compact）。選べる日は開始の日から 28〜182 日で、その幅を1行で書く。選んでから「次へ」
struct GoalSetupDeadlinePage: View {
    let content: GoalSetupFlowContent
    let actions: GoalSetupFlowActions
    let timeZone: () -> TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(content.direction == .gain ? "いつまでに増やしますか" : "いつまでに減らしますか")
                .font(.headline)
            ItemWrappingLayout(spacing: 8, lineSpacing: 8) {
                ForEach(content.deadlineChoices.chips, id: \.day) { chip in
                    chipButton(chip)
                }
            }
            // 選べる幅は DatePicker の幅で伝え、幅の文は添えない
            deadlinePicker
            GoalSetupFooter(page: content.page, goBack: actions.goBack) {
                Button("次へ", action: actions.proceedFromDeadline)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("goal-setup-next")
            }
        }
    }

    private var deadlinePicker: some View {
        DatePicker(
            "期限",
            selection: deadline,
            in: date(
                of: content.deadlineChoices.earliestDay)...date(
                    of: content.deadlineChoices.latestDay),
            displayedComponents: .date
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        .environment(\.timeZone, timeZone())
        .accessibilityIdentifier("goal-setup-deadline-picker")
    }

    private func chipButton(_ chip: GoalDeadlineChoices.Chip) -> some View {
        let selected = chip.day == content.deadline
        let label =
            switch chip.label {
            case .months(let months): "\(months)か月後"
            case .weeks(let weeks): "\(weeks)週後"
            }
        return Button {
            actions.chooseDeadline(chip.day)
        } label: {
            Text(label)
                .font(.footnote)
                // DESIGN.md の preset-chip（高さ 32、左右 12）。押せる範囲は 44 に広げる
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(
                    selected ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule()
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("goal-setup-deadline-chip")
    }

    private var deadline: Binding<Date> {
        Binding(
            get: { date(of: content.deadline) },
            set: { actions.chooseDeadline(CalendarDay(containing: $0, in: timeZone())) }
        )
    }

    private func date(of day: CalendarDay) -> Date {
        day.noon(in: timeZone())
    }
}
