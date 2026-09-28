import { OpenAPIHono } from "@hono/zod-openapi";
import { verificationRoutes } from "./verification-routes";

export const app = new OpenAPIHono<{ Bindings: Env }>();

app.route("/_verify", verificationRoutes);
