/// カードに見せる状態。推定の状態に、送った端末とほかの端末の違いを足したもの
public enum MealCardState: Hashable, Sendable {
    /// 送った端末で、食事の書き込みか写真がまだ送れていない、または推定の状態がまだ届いていない。写真と時刻だけを見せる
    case notSent
    /// ほかの端末で、写真がまだサーバーに届いていない（推定の状態がまだ届いていないときも）。写真の場所に回る印を出し、名前の場所は空にする
    case awaitingPhotos
    case estimating
    case estimated
    case noDishes
    case deferredToNextDay
    case failed

    init(status: MealEstimationStatus?, recordedOnThisDevice: Bool) {
        switch status {
        case nil, .awaitingPhotos:
            // 送った端末は、写真を待っているあいだも送れていないものとして見せる
            self = recordedOnThisDevice ? .notSent : .awaitingPhotos
        case .estimating: self = .estimating
        case .estimated: self = .estimated
        case .noDishes: self = .noDishes
        case .deferredToNextDay: self = .deferredToNextDay
        case .failed: self = .failed
        }
    }
}
