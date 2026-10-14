import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { dailyGuideLimitTypes } from "../domain/daily-guide";
import type { DailyGuideStore } from "../domain/daily-guide-store";
import { dailyGuideTables } from "./daily-guide-tables";

const { dailyGuides, dailyGuideLimitHits } = dailyGuideTables;

export const createDailyGuideStore = (db: DrizzleSqliteDODatabase): DailyGuideStore => ({
  find: (id) => {
    const guide = db.select().from(dailyGuides).where(eq(dailyGuides.id, id)).get();
    if (guide === undefined) {
      return undefined;
    }
    const hits = db
      .select({ limitType: dailyGuideLimitHits.limitType })
      .from(dailyGuideLimitHits)
      .where(eq(dailyGuideLimitHits.dailyGuideId, id))
      .all();
    return {
      ...guide,
      // 行は並びを持たないので、決まりの並びの順にそろえる
      limitHits: dailyGuideLimitTypes.filter((limitType) =>
        hits.some((hit) => hit.limitType === limitType),
      ),
    };
  },
});
