import { instrumentDurableObjectWithSentry } from "@sentry/cloudflare";
import { DurableObject } from "cloudflare:workers";
import { createSentryOptions } from "../observability/create-sentry-options";
import { applyDurableObjectMigrations } from "./apply-durable-object-migrations";
import { durableObjectMigrations } from "./durable-object-migrations";

export const AccountDurableObject = instrumentDurableObjectWithSentry(
  createSentryOptions,
  class extends DurableObject<Env> {
    constructor(ctx: DurableObjectState, env: Env) {
      super(ctx, env);
      applyDurableObjectMigrations(ctx.storage, durableObjectMigrations);
    }

    async deleteRecords(): Promise<void> {
      await this.ctx.storage.deleteAlarm();
      await this.ctx.storage.deleteAll();
    }
  },
);
