export const goalDirections = ["lose", "gain", "maintain"] as const;

export type GoalDirection = (typeof goalDirections)[number];
