import { z } from "@hono/zod-openapi";

export const writeIdSchema = z.string().min(1).openapi({ description: "冪等の鍵" });
