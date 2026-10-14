import { and, eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { RecordId } from "../../domain/record-id";
import { type DailyGuide, dailyGuideLimitTypes } from "../domain/daily-guide";
import type { DailyGuideStore } from "../domain/daily-guide-store";
import { dailyGuideTables } from "./daily-guide-tables";

const { dailyGuides, dailyGuideLimitHits } = dailyGuideTables;

export const createDailyGuideStore = (db: DrizzleSqliteDODatabase): DailyGuideStore => {
  const find = (id: RecordId): DailyGuide | undefined => {
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
  };
  return {
    find,
    findAll: () =>
      db
        .select({ id: dailyGuides.id })
        .from(dailyGuides)
        .all()
        .flatMap(({ id }) => find(id) ?? []),
    findByGoalAndEffectiveDay: (goalId, effectiveOn) => {
      const guide = db
        .select({ id: dailyGuides.id })
        .from(dailyGuides)
        .where(and(eq(dailyGuides.goalId, goalId), eq(dailyGuides.effectiveOn, effectiveOn)))
        .get();
      return guide === undefined ? undefined : find(guide.id);
    },
    insert: ({ limitHits, ...guide }) => {
      db.insert(dailyGuides).values(guide).run();
      for (const limitType of limitHits) {
        db.insert(dailyGuideLimitHits).values({ dailyGuideId: guide.id, limitType }).run();
      }
    },
  };
};
