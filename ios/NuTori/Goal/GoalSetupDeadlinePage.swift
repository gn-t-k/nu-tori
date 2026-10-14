import NuToriAPI
import NuToriCore
import SwiftUI

/// 期限のページ。チップ「1か月後・2か月後・3か月後・6か月後」（6か月後が選べる最後の日を越えるときは「26週後」）と、
/// 「期限」の1行の標準の DatePicker（compact）。選べる日は開始の日から 28〜182 日で、その幅を1行で書く。選んでから「次へ」
struct GoalSetupDeadlinePage: View {
    let flow: GoalSetupFlow
    let timeZone: () -> TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(flow.direction == .gain ? "いつまでに増やしますか" : "いつまでに減らしますか")
                .font(.headline)
            ItemWrappingLayout(spacing: 8, lineSpacing: 8) {
                ForEach(flow.deadlineChoices.chips, id: \.day) { chip in
                    chipButton(chip)
                }
            }
            DatePicker(
                "期限",
                selection: deadline,
                in: date(
                    of: flow.deadlineChoices.earliestDay)...date(of: flow.deadlineChoices.latestDay),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .environment(\.timeZone, timeZone())
            .accessibilityIdentifier("goal-setup-deadline-picker")
            Text(rangeText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            GoalSetupFooter(flow: flow) {
                Button("次へ") {
                    Task { await flow.proceedFromDeadline() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("goal-setup-next")
            }
        }
    }

    private func chipButton(_ chip: GoalDeadlineChoices.Chip) -> some View {
        let selected = chip.day == flow.deadline
        let label =
            switch chip.label {
            case .months(let months): "\(months)か月後"
            case .weeks(let weeks): "\(weeks)週後"
            }
        return Button {
            flow.chooseDeadline(chip.day)
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
            get: { date(of: flow.deadline) },
            set: { flow.chooseDeadline(CalendarDay(containing: $0, in: timeZone())) }
        )
    }

    /// 「10月22日〜4月13日の日を選べます（4〜26週）。」
    private var rangeText: String {
        let earliest = flow.deadlineChoices.earliestDay
        let latest = flow.deadlineChoices.latestDay
        return
            "\(earliest.month)月\(earliest.day)日〜\(latest.month)月\(latest.day)日の日を選べます（4〜26週）。"
    }

    /// その日の正午。DatePicker は時刻を持つので、夏時間の切り替えで日がずれないよう日の真ん中にする
    private func date(of day: CalendarDay) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone()
        return calendar.date(
            from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)) ?? .now
    }
}
