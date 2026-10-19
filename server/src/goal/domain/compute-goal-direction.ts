import { classifyGoal } from "./classify-goal";
import type { GoalDirection } from "./goal-direction";

// 目標の向き。分け方は classifyGoal に置く
export const computeGoalDirection = (goal: Parameters<typeof classifyGoal>[0]): GoalDirection =>
  classifyGoal(goal).direction;
