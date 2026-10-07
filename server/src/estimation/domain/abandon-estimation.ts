import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import { applyDishEstimation } from "./apply-dish-estimation";
import type { EstimationTarget } from "./estimation-target";
import type { EstimationWrites } from "./estimation-writes";

// 推定を諦める。料理が対象なら、推定できなかったとして料理に当てるかを決めて当てる（apply-dish-estimation.ts）
export const abandonEstimation = (
  stores: Pick<RecordKindStores, "dish" | "ingredient">,
  writes: EstimationWrites,
  addChange: (change: RecordChangeTarget<"dish" | "ingredient">) => void,
  abandonment: { estimationId: string; target: EstimationTarget; abandonedAt: Date },
): void => {
  writes.abandon(abandonment);
  const { estimationId, target } = abandonment;
  if (target.type === "dish") {
    applyDishEstimation(stores, addChange, {
      dishId: target.dishId,
      estimationId,
      estimated: undefined,
    });
  }
};
