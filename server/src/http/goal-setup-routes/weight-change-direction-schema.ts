import { z } from "@hono/zod-openapi";

// 減量・増量の向き。期限を持つ要求が載せる
export const weightChangeDirectionSchema = z.enum(["lose", "gain"]);
