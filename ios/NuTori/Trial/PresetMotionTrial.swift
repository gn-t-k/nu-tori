import SwiftUI

/// 試作（#1133）: 入力欄のプリセットの行の出入りの動きの案。TestFlight の版で、入力欄の上の右端の切り替えから選ぶ。
/// 決めたら、決めた案だけを `TimelineComposer` に残し、このファイルを消す
enum PresetMotionTrial: String, CaseIterable, Identifiable {
    case still
    case fade
    case fadeInOnly
    case sink
    case shrink

    static let storageKey = "trial.presetMotion"

    var id: Self { self }

    var title: String {
        switch self {
        case .still: "今のまま"
        case .fade: "薄れながら詰まる"
        case .fadeInOnly: "出るときだけ薄れ"
        case .sink: "沈みながら薄れる"
        case .shrink: "縮みながら薄れる"
        }
    }

    /// 行が出入りするときの動き。nil なら動かさない。長さは入力欄の丸と「送る」と同じ（DESIGN.md の Motion）
    func animation(showing: Bool) -> Animation? {
        switch self {
        case .still: nil
        case .fadeInOnly: showing ? .smooth(duration: 0.2) : nil
        case .fade, .sink, .shrink: .smooth(duration: 0.2)
        }
    }

    /// 「視差効果を減らす」では薄れだけにする
    func transition(reduceMotion: Bool) -> AnyTransition {
        switch self {
        case .still, .fade, .fadeInOnly: .opacity
        case .sink: reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8))
        case .shrink:
            reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom))
        }
    }
}

/// 入力欄の上の右端に置く、案の切り替え
struct PresetMotionTrialSwitch: View {
    @Binding var selection: PresetMotionTrial

    var body: some View {
        Menu {
            Picker("プリセットの出入り", selection: $selection) {
                ForEach(PresetMotionTrial.allCases) { trial in
                    Text(trial.title).tag(trial)
                }
            }
        } label: {
            // DESIGN.md の標準の余白と押せる範囲 44 に従わない。TestFlight でだけ出す試作の切り替えで、入力欄の高さを変えずに置くため。
            // 押せる範囲は、並べる高さを変えずに上下へ 12 ずつ広げて 44 にする
            Text("試作: \(selection.title)")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: Capsule())
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .padding(.vertical, -12)
        }
    }
}
