import type { RecordId } from "../../../domain/record-id";
import type { durableObjectFactory } from "../../../durable-object/testing/durable-object-factory";

// 期限が 2026-11-30 の減量の目標を置き、その ID を返す
export const seedWeightChangeGoal = async (
  factory: ReturnType<typeof durableObjectFactory>,
): Promise<RecordId> => {
  const goal = await factory.goals.create({ startingWeightTrendKg: 74, targetWeightKg: 70 });
  await factory.weightChangeGoals.create({ goalId: goal.id, deadlineOn: "2026-11-30" });
  return goal.id;
};
