import { instrumentDurableObjectWithSentry, setUser } from "@sentry/cloudflare";
import { DurableObject } from "cloudflare:workers";
import { recordFirstSignIn } from "../domain/record-first-sign-in";
import { createSentryOptions } from "../observability/create-sentry-options";
import { applyDurableObjectMigrations } from "./apply-durable-object-migrations";
import { createFirstSignInStore } from "./create-first-sign-in-store";
import { durableObjectMigrations } from "./durable-object-migrations";

// 受け口は呼ぶたびに accountId を渡す。Sentry の報告に user の ID として付けるため
export const AccountDurableObject = instrumentDurableObjectWithSentry(
  createSentryOptions,
  class extends DurableObject<Env> {
    constructor(ctx: DurableObjectState, env: Env) {
      super(ctx, env);
      applyDurableObjectMigrations(ctx.storage, durableObjectMigrations);
    }

    recordFirstSignIn(
      accountId: string,
      signIn: { signedInAt: Date; timeZone: string | undefined },
    ): void {
      setUser({ id: accountId });
      recordFirstSignIn(createFirstSignInStore(this.ctx.storage.sql), signIn);
    }

    async deleteRecords(accountId: string): Promise<void> {
      setUser({ id: accountId });
      await this.ctx.storage.deleteAlarm();
      await this.ctx.storage.deleteAll();
    }
  },
);

export type AccountDurableObject = InstanceType<typeof AccountDurableObject>;
