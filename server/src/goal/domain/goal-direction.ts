import { weightChangeDirections } from "./weight-change-direction";

export const goalDirections = [...weightChangeDirections, "maintain"] as const;

export type GoalDirection = (typeof goalDirections)[number];
