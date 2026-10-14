import type { FastestEndReason } from "./fastest-end-reason";

// 自分で決めた目標体重を受け付けない理由。向きの側に出ないか、いちばん速い端を越えた
export type CustomTargetWeightRejectionReason = "not_on_direction_side" | FastestEndReason;
