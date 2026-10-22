import { match } from "ts-pattern";
import type { FreeTrial } from "../compute-free-trial";

// 推定と返事の判定に使う。予定・依頼の数える日（YYYY-MM-DD）で比べ、タイムゾーンを持ち出さない
export const isWithinFreeTrial = (freeTrial: FreeTrial, countedOn: string): boolean =>
  match(freeTrial)
    .with({ type: "available" }, ({ lastDay }) => countedOn <= lastDay)
    .with({ type: "used_by_earlier_account" }, () => false)
    .exhaustive();
