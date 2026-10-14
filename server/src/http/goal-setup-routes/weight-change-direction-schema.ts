import { z } from "@hono/zod-openapi";
import { weightChangeDirections } from "../../goal/domain/weight-change-direction";

// 減量・増量の向き。期限を持つ要求が載せる
export const weightChangeDirectionSchema = z.enum(weightChangeDirections);
