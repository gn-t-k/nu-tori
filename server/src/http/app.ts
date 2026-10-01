import { OpenAPIHono } from "@hono/zod-openapi";
import { sentry } from "@sentry/hono/cloudflare";
import { createSentryOptions } from "../observability/create-sentry-options";
import { accountRoutes } from "./account-routes";
import { appleServerNotificationRoutes } from "./apple-server-notification-routes";
import { e2eSessionRoutes } from "./e2e-session-routes";
import { mealPhotoRoutes } from "./meal-photo-routes";
import { observeRequest } from "./observe-request";
import { sessionRoutes } from "./session-routes";
import { syncRoutes } from "./sync-routes";

export const app = new OpenAPIHono<{ Bindings: Env }>();

app
  .use(sentry(app, createSentryOptions))
  .use(observeRequest)
  .route("/", sessionRoutes)
  .route("/", e2eSessionRoutes)
  .route("/", accountRoutes)
  .route("/", syncRoutes)
  .route("/", mealPhotoRoutes)
  .route("/", appleServerNotificationRoutes);

app.openAPIRegistry.registerComponent("securitySchemes", "session", {
  type: "http",
  scheme: "bearer",
});
