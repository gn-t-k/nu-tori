import { createWeightRecordWrite } from "../../../weight-record/http/testing/create-weight-record-write";
import { pushSyncWrites } from "../../sync-routes/testing/push-sync-writes";

// 渡した日（YYYY-MM-DD）ごとに、日本時間の朝 9 時の体重記録を同期で送る
export const recordDailyWeights = async (
  sessionToken: string,
  calendarDays: readonly string[],
  weightKg: number,
): Promise<void> => {
  const response = await pushSyncWrites(sessionToken, {
    writes: calendarDays.map((calendarDay) =>
      createWeightRecordWrite({
        weightRecord: {
          weightKg,
          measuredAt: Date.parse(`${calendarDay}T00:00:00Z`),
          timeZone: "Asia/Tokyo",
        },
      }),
    ),
  });
  if (response.status !== 200) {
    throw new Error(`体重記録を送れなかった: ${response.status}`);
  }
};
