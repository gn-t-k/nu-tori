import { DurableObject } from "cloudflare:workers";
import { applyDurableObjectMigrations } from "./apply-durable-object-migrations";
import { durableObjectMigrations } from "./durable-object-migrations";

export class AccountDurableObject extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    applyDurableObjectMigrations(ctx.storage, durableObjectMigrations);
  }
}
