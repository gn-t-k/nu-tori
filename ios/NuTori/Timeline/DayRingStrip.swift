import NuToriCore
import SwiftUI

struct DayRingStrip: View {
    let weeks: [RingStrip.Week]
    /// タイムラインで見ている日。帯は、その日の週を出す
    let selectedDay: CalendarDay
    let today: CalendarDay
    /// 読み込み中は、使い始めた日がまだ無いので開けない
    let openableDays: ClosedRange<CalendarDay>?
    let onSelect: (CalendarDay) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(weeks, id: \.monday) { week in
                    weekRow(week)
                        .containerRelativeFrame(.horizontal)
                        .id(week.monday)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $shownMonday)
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("day-ring-strip")
        .onChange(of: selectedDay.startOfWeek, initial: true) { _, monday in
            guard weeks.contains(where: { $0.monday == monday }), shownMonday != monday else {
                return
            }
            shownMonday = monday
        }
    }

    init(
        weeks: [RingStrip.Week],
        selectedDay: CalendarDay,
        today: CalendarDay,
        openableDays: ClosedRange<CalendarDay>?,
        onSelect: @escaping (CalendarDay) -> Void
    ) {
        self.weeks = weeks
        self.selectedDay = selectedDay
        self.today = today
        self.openableDays = openableDays
        self.onSelect = onSelect
        _shownMonday = State(initialValue: selectedDay.startOfWeek)
    }

    @State private var shownMonday: CalendarDay?

    private func weekRow(_ week: RingStrip.Week) -> some View {
        HStack(spacing: 0) {
            ForEach(week.slots, id: \.day) { slot in
                slotView(slot)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    @ViewBuilder private func slotView(_ slot: RingStrip.Slot) -> some View {
        switch slot {
        case .beforeFirstDay(let day):
            column(day: day, ring: .hidden)
                .accessibilityLabel(TimelineDayText.label(for: day))
                .accessibilityIdentifier(identifier("day-label", day))
        case .ring(let day, let dayRing):
            let hasWeightRecord = dayRing.hasWeightRecord
            let ring: Ring = hasWeightRecord ? .marked : .empty
            if openableDays?.contains(day) == true {
                Button {
                    onSelect(day)
                } label: {
                    column(day: day, ring: ring)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TimelineDayText.label(for: day))
                .accessibilityValue(hasWeightRecord ? "体重の記録あり" : "体重の記録なし")
                .accessibilityAddTraits(day == selectedDay ? .isSelected : [])
                .accessibilityIdentifier(identifier("ring", day))
            } else {
                column(day: day, ring: ring)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(TimelineDayText.label(for: day))
                    .accessibilityIdentifier(identifier("ring", day))
            }
        }
    }

    private func column(day: CalendarDay, ring: Ring) -> some View {
        VStack {
            ringMark(ring)
            Text(TimelineDayText.weekdaySymbol(for: day))
                .font(.caption2)
                .fontWeight(day == selectedDay ? .semibold : .regular)
                .foregroundStyle(weekdayStyle(day: day, ring: ring))
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .background {
            if day == selectedDay {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.tertiarySystemFill))
            }
        }
        // コンポーネントの見本は、まだ来ていない日を 0.45 で薄くする。見ている日は薄くしない
        .opacity(day > today && day != selectedDay ? 0.45 : 1)
    }

    @ViewBuilder private func ringMark(_ ring: Ring) -> some View {
        let diameter: CGFloat = 28
        let lineWidth: CGFloat = 4.5
        switch ring {
        case .hidden:
            Color.clear.frame(width: diameter, height: diameter)
        case .empty, .marked:
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
                .frame(width: diameter, height: diameter)
                .overlay {
                    if ring == .marked {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 7, height: 7)
                    }
                }
        }
    }

    private func weekdayStyle(day: CalendarDay, ring: Ring) -> HierarchicalShapeStyle {
        if day == selectedDay {
            return .primary
        }
        if ring == .hidden {
            return .tertiary
        }
        return .secondary
    }

    private func identifier(_ prefix: String, _ day: CalendarDay) -> String {
        "\(prefix)-\(TimelineDayText.startedOn(for: day))"
    }

    private enum Ring: Equatable {
        case hidden
        case empty
        case marked
    }
}

extension RingStrip.Week {
    fileprivate var monday: CalendarDay {
        slots[0].day
    }
}
