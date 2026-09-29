import NuToriCore
import SwiftUI

struct DaySummarySheet: View {
    let timeline: Timeline
    let onSeeOnTimeline: (CalendarDay) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let weight = shown?.representativeWeight {
                        LabeledContent("この日の体重") {
                            VStack(alignment: .trailing) {
                                Text(weight.record.kilogramsLabel)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                if weight.otherRecordCount > 0 {
                                    Text("ほか\(weight.otherRecordCount)件")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("記録なし")
                    }
                }
                Section {
                    Button("タイムラインでこの日を見る") {
                        onSeeOnTimeline(shownDay)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    dayNavigation
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("day-summary")
    }

    init(
        timeline: Timeline, day: CalendarDay, onSeeOnTimeline: @escaping (CalendarDay) -> Void
    ) {
        self.timeline = timeline
        self.onSeeOnTimeline = onSeeOnTimeline
        _shownDay = State(initialValue: day)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var shownDay: CalendarDay

    private var dayNavigation: some View {
        HStack {
            Button {
                guard let previous else { return }
                withAnimation { shownDay = previous }
            } label: {
                Image(systemName: "chevron.left")
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("前の日")
            .disabled(previous == nil)

            Text(TimelineDayText.label(for: shownDay))
                .font(.headline)

            Button {
                guard let next else { return }
                withAnimation { shownDay = next }
            } label: {
                Image(systemName: "chevron.right")
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("次の日")
            .disabled(next == nil)
        }
    }

    private var shown: Timeline.Day? {
        timeline.days.first { $0.day == shownDay }
    }

    private var previous: CalendarDay? {
        let day = shownDay.advanced(by: -1)
        return timeline.dayRange.contains(day) ? day : nil
    }

    private var next: CalendarDay? {
        let day = shownDay.advanced(by: 1)
        return timeline.dayRange.contains(day) ? day : nil
    }
}
