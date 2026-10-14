import SwiftUI

/// 体重の値の欄とステッパーの角（DESIGN.md の value-field と stepper-button）
nonisolated struct WeightControlShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: 10).path(in: rect)
    }
}
