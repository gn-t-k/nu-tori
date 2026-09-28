import { OpenAPIHono } from "@hono/zod-openapi";

export const app = new OpenAPIHono<{ Bindings: Env }>();
