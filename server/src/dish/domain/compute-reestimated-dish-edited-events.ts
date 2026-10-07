import type { UsageEvent } from "../../domain/usage-event";
import type { DishStore } from "./dish-store";

// 推定し直しを当てた料理を、使う人がまた直した・消したときの出来事。直す・消す書き込みを当てるときに、
// その料理のいちばん新しい当てた推定し直しの終わりを読む（消すときは消す前に読む）。推定し直しを当てていなければ送らない
export const computeReestimatedDishEditedEvents = (
  dishStore: DishStore,
  dishId: string,
  action: "corrected" | "deleted",
  editedAt: Date,
): UsageEvent[] => {
  const endedAt = dishStore.findNewestReestimationEndedAt(dishId);
  return endedAt === undefined
    ? []
    : [
        {
          name: "reestimated_dish_edited",
          action,
          secondsFromReestimationEnded: Math.round((editedAt.getTime() - endedAt.getTime()) / 1000),
        },
      ];
};
