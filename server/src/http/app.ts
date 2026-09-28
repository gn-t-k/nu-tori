import { OpenAPIHono } from "@hono/zod-openapi";
import { accountRoutes } from "./account-routes";
import { appleServerNotificationRoutes } from "./apple-server-notification-routes";
import { sessionRoutes } from "./session-routes";

export const app = new OpenAPIHono<{ Bindings: Env }>()
  .route("/", sessionRoutes)
  .route("/", accountRoutes)
  .route("/", appleServerNotificationRoutes);

app.openAPIRegistry.registerComponent("securitySchemes", "session", {
  type: "http",
  scheme: "bearer",
});
