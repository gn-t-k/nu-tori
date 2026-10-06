import {
  pullSyncChanges,
  type PullResult,
} from "../../../http/sync-routes/testing/pull-sync-changes";
import { requireLastSequence } from "../../../http/sync-routes/testing/require-last-sequence";
import { recordPhotographedMeal } from "./record-photographed-meal";
import { runEstimationAlarm } from "./run-estimation-alarm";

// 写真1枚の食事を送り、アラームで写真の推定を済ませる。偽の提供元の既定の答えなら、親子丼（1 杯。鶏もも肉 80 g・ご飯 200 g）と緑茶ができる。
// 料理と材料の ID を名前で引けるようにして返す。lastSequence は推定のあとの最後の変更の通し番号
export const recordEstimatedMeal = async (accountId: string, sessionToken: string) => {
  const mealId = await recordPhotographedMeal(sessionToken);
  await runEstimationAlarm(accountId);
  const { changes } = await (await pullSyncChanges(sessionToken)).json<PullResult>();
  const recordIdNamed = (kind: string, name: string): string => {
    const found = changes.find((change) => change.kind === kind && change.record["name"] === name);
    if (found === undefined) {
      throw new Error(`推定で ${kind} の ${name} ができていない`);
    }
    return found.recordId;
  };
  return {
    mealId,
    dishId: (name: string) => recordIdNamed("dish", name),
    ingredientId: (name: string) => recordIdNamed("ingredient", name),
    lastSequence: requireLastSequence(changes),
  };
};
