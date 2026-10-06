import { vi } from "vitest";
import { runEstimationAlarm } from "../../../estimation/http/testing/run-estimation-alarm";
import {
  pullSyncChanges,
  type PullResult,
} from "../../../http/sync-routes/testing/pull-sync-changes";

// 名前を直した料理の推定し直しを、アラームで済ませて料理に当てる（材料が置き換わり、前の推定の材料が残る）。置き換えた材料の ID を返す。
// 偽の時計を1秒進めてから動かす。止まった時計のままだと、推定し直しの終わりが写真の推定の終わりと同じ時刻になり、
// どちらがいちばん新しい当てた推定かが決まらないため
export const reestimateRenamedDish = async (
  accountId: string,
  sessionToken: string,
  dishId: string,
): Promise<string[]> => {
  vi.setSystemTime(Date.now() + 1000);
  if (!(await runEstimationAlarm(accountId))) {
    throw new Error("推定し直しの予定のアラームが張られていない");
  }
  const { changes } = await (await pullSyncChanges(sessionToken)).json<PullResult>();
  const replacingIngredientIds = changes
    .filter(({ kind, record }) => kind === "ingredient" && record["dishId"] === dishId)
    .map(({ recordId }) => recordId);
  if (replacingIngredientIds.length === 0) {
    throw new Error("推定し直しが当たらなかった");
  }
  return replacingIngredientIds;
};
