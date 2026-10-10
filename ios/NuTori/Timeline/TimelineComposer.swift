import Foundation
import NuToriCore
import SwiftUI
import UIKit

/// タイムラインの下に固定する入力欄。上の行に左から「撮る」「写真」「体重」と、残りの幅の書く欄。
/// 今日の体重が未記録のあいだは、「体重」をカプセルにして丸の行の下に全幅で置く（書く欄の幅が記録の前後で変わらないように）。
/// カメラを許可していない人が「撮る」を押したら、そのすぐ上に知らせを出す
struct TimelineComposer: View {
    let weightRecordedToday: Bool
    /// 体重のシートを開く前の、ヘルスケアの許可を求めているあいだ
    let preparingWeightEntry: Bool
    let showsCameraNotice: Bool
    let onCapture: () -> Void
    let onPickPhotos: () -> Void
    let onWeight: () -> Void
    let onPresetTapped: (TextPreset) -> Void
    /// 送れるときだけ呼ぶ。呼んだあと書く欄を空にする
    let onSendText: (TextDraft) -> Void

    init(
        weightRecordedToday: Bool,
        preparingWeightEntry: Bool,
        showsCameraNotice: Bool,
        initialDraft: TextDraft,
        onCapture: @escaping () -> Void,
        onPickPhotos: @escaping () -> Void,
        onWeight: @escaping () -> Void,
        onPresetTapped: @escaping (TextPreset) -> Void,
        onSendText: @escaping (TextDraft) -> Void
    ) {
        self.weightRecordedToday = weightRecordedToday
        self.preparingWeightEntry = preparingWeightEntry
        self.showsCameraNotice = showsCameraNotice
        self.onCapture = onCapture
        self.onPickPhotos = onPickPhotos
        self.onWeight = onWeight
        self.onPresetTapped = onPresetTapped
        self.onSendText = onSendText
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        VStack(spacing: 8) {
            if showsCameraNotice {
                cameraNotice
                    .padding(.horizontal)
            }
            VStack(spacing: 8) {
                if draft.showsPresets {
                    presets
                }
                HStack(alignment: .bottom, spacing: 12) {
                    Button(action: onCapture) {
                        circle(systemName: "camera.fill", filled: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("撮る")
                    .accessibilityIdentifier("composer-capture")
                    Button(action: onPickPhotos) {
                        circle(systemName: "photo.on.rectangle", filled: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("写真")
                    .accessibilityIdentifier("composer-photos")
                    if weightRecordedToday && !writing {
                        Button(action: onWeight) {
                            circle(systemName: "scalemass.fill", filled: false)
                        }
                        .buttonStyle(.plain)
                        .disabled(preparingWeightEntry)
                        .accessibilityLabel("体重")
                        .accessibilityIdentifier("composer-weight")
                    }
                    field
                }
                if !weightRecordedToday && !writing {
                    unrecordedWeightCapsule
                }
                if let remaining = draft.remainingLength {
                    Text("残り \(remaining)")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("composer-remaining")
                }
                aiReplyNote
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    @State private var draft: TextDraft
    @FocusState private var fieldFocused: Bool

    /// 書いているあいだ（欄を選んでいるか、文字がある）は、「体重」を隠して書く欄を広げる。「撮る」「写真」は残す
    private var writing: Bool { fieldFocused || !draft.text.isEmpty }

    /// 文字を大きくしたとき、アイコンに合わせて丸も大きくする。3つの丸と書く欄が画面の幅に収まるところで止める
    @ScaledMetric private var scaledButtonSize: CGFloat = 44
    private var buttonSize: CGFloat { min(scaledButtonSize, 88) }
    @Environment(\.openURL) private var openURL

    /// 押すと文面を入れてキーボードを出す。送らない
    private var presets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TextPreset.allCases, id: \.self) { preset in
                    Button {
                        draft.insert(preset)
                        fieldFocused = true
                        onPresetTapped(preset)
                    } label: {
                        Text(preset.title)
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                            .overlay(Capsule().stroke(Color(.separator), lineWidth: 0.5))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("preset-chip")
                }
            }
        }
        .scrollClipDisabled()
    }

    /// 1行から始まり5行まで伸びる。「送る」は文字を入れたときだけ欄の右端に出し、送れないあいだは押せなくする
    private var field: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("書く", text: $draft.text, axis: .vertical)
                .font(.body)
                .lineLimit(1...5)
                .focused($fieldFocused)
                .padding(.vertical, 7)
                .accessibilityIdentifier("composer-field")
            if !draft.text.isEmpty {
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .fontWeight(.semibold)
                }
                // 押せないときの見た目をシステムに任せるため、塗ったボタンの標準の形にする
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .padding(4)
                // 押せる範囲を 44 に広げる。並べる幅は広げず、書く欄の高さを「送る」を出す前後で変えない
                .padding(4)
                .contentShape(Rectangle())
                .padding(-4)
                .disabled(!draft.canSend)
                .accessibilityLabel("送る")
                .accessibilityIdentifier("composer-send")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, draft.text.isEmpty ? 14 : 0)
        .frame(minHeight: 36)
        .background(Color(.secondarySystemGroupedBackground), in: fieldShape)
        .overlay(fieldShape.stroke(Color(.separator), lineWidth: 0.5))
        // 1行のとき、丸のボタンと縦の中心をそろえる（行は下端でそろえ、伸びた欄は上へ広がる）
        .padding(.bottom, max(0, (buttonSize - 36) / 2))
    }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18)
    }

    /// 文字の大きさによらず文字のカプセルにし、記録を促す。記録すると丸の行の体重計に戻る
    private var unrecordedWeightCapsule: some View {
        Button(action: onWeight) {
            Text("体重を記録")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .frame(height: buttonSize)
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
        .disabled(preparingWeightEntry)
        .accessibilityLabel("体重を記録")
        .accessibilityIdentifier("composer-weight-unrecorded")
    }

    /// Anthropic の Usage Policy（消費者向けのチャットボットは、少なくとも各チャットセッションの始めに AI であることを伝える）のための1行で、
    /// 消したり … で切ったりしない（ADR-0018、#29、#412 の6）。画面に「AI」と出す例外は、ここだけ（DESIGN.md の Don't）。
    /// ボタンにせず、ふつうの文としてボタンの行のあとに読ませる
    private var aiReplyNote: some View {
        Text("AI が読んで返事をします")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("composer-ai-reply-note")
    }

    /// ダイアログにせず、全幅の白いカードで知らせる。記録にも同期にも残さない
    private var cameraNotice: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("カメラを許可していないため、撮れません。iPhone の設定で許可すると撮れます。")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("設定を開く") {
                if let settings = URL(string: UIApplication.openSettingsURLString) {
                    openURL(settings)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("camera-permission-notice")
    }

    private func send() {
        guard draft.canSend else { return }
        onSendText(draft)
        draft = TextDraft()
    }

    /// 塗った丸は Primary の地に白、灰色の丸は Fill の地に Primary
    private func circle(systemName: String, filled: Bool) -> some View {
        Image(systemName: systemName)
            .frame(width: buttonSize, height: buttonSize)
            .background(filled ? Color.accentColor : Color(.tertiarySystemFill), in: Circle())
            .foregroundStyle(filled ? Color.white : Color.accentColor)
    }
}
